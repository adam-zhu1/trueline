#!/usr/bin/env python3
"""Experiment 2: handheld tracking, simulated on the tripod benchmark clips.

    .venv/bin/python experiments/autocal_handheld/exp2_handheld.py --level moderate
    .venv/bin/python experiments/autocal_handheld/exp2_handheld.py --level mild strong --methods klt_key ecc_key --masks lane

For each labelled clip: warp every frame from 0 to the last labelled frame by
a known handheld motion (handheld.Motion, with camera-motion blur), register
it back to frame 0 with each method and mask, and score
  - the calibration carried to every frame: corner px, board error across
    the lane at the arrows (15 ft) and at the pins (59.5 ft);
  - the metrics: the hand-labelled ball positions (labels.json) as they would
    appear in the moving video, mapped to the lane through the estimated
    per-frame calibration vs the true one, then the benchmark's label metric
    rules (arrows crossing, entry board/angle from a quadratic over 45+ ft,
    launch speed from a feet-vs-time slope over the first 20 ft).
Registration runs at half resolution. Writes out/exp2_<level>.json.
"""
import argparse
import json
import math
import sys
import time
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import handheld as HH  # noqa: E402

LABELS = json.loads((C.REPO / "experiments/accuracy_bench/labels.json").read_text())["clips"]
INCHES_PER_BOARD = 41.5 / 39
SCALE = 0.5


def label_metrics(pts):
    """pts: [(t s, board, feet)] -> same rules as bench.label_metrics."""
    pts = sorted(pts)
    m = {"arrows": None, "entry": None, "entry_angle": None, "speed": None}
    for (t0, b0, f0), (t1, b1, f1) in zip(pts, pts[1:]):
        g0, g1 = f0 - C.bench.arrow_feet(b0), f1 - C.bench.arrow_feet(b1)
        if g0 < 0 <= g1 and f1 - f0 < 4:
            u = g0 / (g0 - g1)
            m["arrows"] = b0 + u * (b1 - b0)
            break
    tail = [(b, f) for _, b, f in pts if f >= 45]
    if len(tail) >= 6 and tail[-1][1] >= 55 and tail[-1][1] - tail[0][1] >= 8:
        bb, ff = np.array(tail).T
        q = np.polyfit(ff, bb, 2)
        m["entry"] = float(np.polyval(q, 59.5))
        m["entry_angle"] = math.degrees(math.atan((2 * q[0] * 59.5 + q[1]) * INCHES_PER_BOARD / 12))
    head = [(t, f) for t, _, f in pts if f <= 20]
    if len(head) >= 5 and head[-1][1] - head[0][1] >= 8:
        tt, ff = np.array(head).T
        m["speed"] = float(np.polyfit(tt, ff, 1)[0] * 0.681818)
    return m


def load_frames(video, n):
    cap = cv2.VideoCapture(video)
    out = []
    for _ in range(n):
        ok, fr = cap.read()
        if not ok:
            break
        g = cv2.cvtColor(fr, cv2.COLOR_BGR2GRAY)
        out.append(cv2.resize(g, None, fx=SCALE, fy=SCALE, interpolation=cv2.INTER_AREA))
    cap.release()
    return out


def run_clip(cid, clip, levels, methods, masks, seed, blur=True):
    lab = LABELS[cid]
    fps = 30.0 if cid != "portfolio_60" else 60.0
    last = max(f["frame"] for f in lab["frames"]) + 3
    frames = load_frames(clip["video"], last + 1)
    h, w = frames[0].shape
    W_full, H_full = w / SCALE, h / SCALE
    H0 = C.lane_to_image(C.corners_array(clip))      # lane -> frame-0 full-res px
    corners0 = C.corners_array(clip)
    S = np.diag([SCALE, SCALE, 1.0])
    Si = np.linalg.inv(S)
    out = {}
    # The tripod clips are not perfectly still (the propped phone settles
    # and jumps when the ball lands). Measure that with the same keyframe
    # registration on the untouched footage; the simulated truth is the
    # synthetic motion on top of it.
    reg = HH.Registrar("klt_key", "lane", frames[0], H0, SCALE)
    D = [np.eye(3)] + [Si @ reg.step(g) @ S for g in frames[1:]]
    lab_frames = [int(f["frame"]) for f in lab["frames"]]
    d_corner = np.array([np.linalg.norm(C.project(Dt, corners0) - corners0, axis=1).max() for Dt in D])
    d_pins = np.array([C.board_error(H0, Dt @ H0, 59.5)[0] for Dt in D])
    pts_fixed, pts_drift = [], []
    for f in lab["frames"]:
        i = int(f["frame"])
        p = np.array([[f["x"], f["y"] + f["r"]]])
        lf = C.project(np.linalg.inv(H0), p)[0]
        ld = C.project(np.linalg.inv(D[i] @ H0), p)[0]
        pts_fixed.append((i / fps, lf[0] * 39, lf[1]))
        pts_drift.append((i / fps, ld[0] * 39, ld[1]))
    out["tripod_drift"] = {
        "corner_px_max": float(d_corner.max()), "corner_px_throw_max": float(d_corner[min(lab_frames):].max()),
        "corner_px_last": float(d_corner[-1]), "pins_board_max": float(d_pins.max()),
        "pins_board_throw_median": float(np.median(d_pins[min(lab_frames):])),
        "metrics_fixed": label_metrics(pts_fixed), "metrics_drift_corrected": label_metrics(pts_drift)}
    print(f"  {cid} tripod drift: corners max {d_corner.max():.1f} px, during throw {d_corner[min(lab_frames):].max():.1f} px, "
          f"pins {d_pins.max():.2f} bd", file=sys.stderr)
    for level in levels:
        mo = HH.Motion(level, fps, W_full, H_full, seed=seed)
        exposure = 1 / (2 * fps) if blur else 0
        t0 = time.time()
        rendered = [HH.render(f, mo, i / fps, exposure, scale=SCALE, samples=5 if blur else 1)
                    for i, f in enumerate(frames)]
        render_s = time.time() - t0
        W_true = [mo.W(i / fps) @ D[i] for i in range(len(frames))]
        # how far the camera actually moved: deck displacement in boards
        ang = np.array([mo.params(i / fps)[0] for i in range(len(frames))])
        res_level = {"render_s": render_s, "max_rot_deg": float(np.abs(ang).max()),
                     "rms_rot_deg": float(np.sqrt((ang ** 2).mean()))}
        combos = [("none", "stale")] + [(m, k) for m in methods for k in masks]
        for method, mask in combos:
            t0 = time.time()
            G_est = [np.eye(3)]
            reg = None
            if method != "none":
                reg = HH.Registrar(method, mask, rendered[0], H0, SCALE)
                for g in rendered[1:]:
                    G_est.append(Si @ reg.step(g) @ S)
            else:
                G_est = [np.eye(3)] * len(frames)
            secs = time.time() - t0
            cerr, a_err, p_err = [], [], []
            for i in range(len(frames)):
                Ht = W_true[i] @ H0
                He = G_est[i] @ H0
                ct = C.project(W_true[i], corners0)
                ce = C.project(G_est[i], corners0)
                cerr.append(np.linalg.norm(ct - ce, axis=1).mean())
                a_err.append(C.board_error(Ht, He, 15.0)[0])
                p_err.append(C.board_error(Ht, He, 59.5)[0])
            # metrics from the labelled balls
            pts_true, pts_est = [], []
            for f in lab["frames"]:
                i = int(f["frame"])
                p = np.array([[f["x"], f["y"] + f["r"]]])
                q = C.project(mo.W(i / fps), p)             # where the moving camera saw it
                lt = C.project(np.linalg.inv(W_true[i] @ H0), q)[0]   # = drift-corrected tripod
                le = C.project(np.linalg.inv(G_est[i] @ H0), q)[0]
                pts_true.append((i / fps, lt[0] * 39, lt[1]))
                pts_est.append((i / fps, le[0] * 39, le[1]))
            mt, me = label_metrics(pts_true), label_metrics(pts_est)
            ball_board = [abs(a[1] - b[1]) for a, b in zip(pts_true, pts_est)]
            lab_frames = [int(f["frame"]) for f in lab["frames"]]
            cerr, a_err, p_err = map(np.array, (cerr, a_err, p_err))
            res_level[f"{method}/{mask}"] = {
                "seconds": secs, "ms_per_frame": 1000 * secs / max(1, len(frames) - 1),
                "lost_frames": reg.lost if reg else 0,
                "median_inliers": float(np.median(reg.inliers)) if reg and reg.inliers else None,
                "corner_px_median": float(np.median(cerr)), "corner_px_p95": float(np.percentile(cerr, 95)),
                "corner_px_max": float(cerr.max()),
                "arrows_board_median": float(np.median(a_err)), "arrows_board_p95": float(np.percentile(a_err, 95)),
                "pins_board_median": float(np.median(p_err)), "pins_board_p95": float(np.percentile(p_err, 95)),
                "pins_board_max": float(p_err.max()),
                "pins_board_throw_max": float(p_err[min(lab_frames):].max()),
                "ball_board_median": float(np.median(ball_board)), "ball_board_max": float(np.max(ball_board)),
                "metrics_true": mt, "metrics_est": me,
            }
            r = res_level[f"{method}/{mask}"]
            print(f"  {cid} {level} {method}/{mask}: corners {r['corner_px_median']:.1f}/{r['corner_px_p95']:.1f} px, "
                  f"pins {r['pins_board_median']:.2f}/{r['pins_board_p95']:.2f} bd, "
                  f"entry {C.fmt(me['entry'], 2)} vs {C.fmt(mt['entry'], 2)}, {r['ms_per_frame']:.0f} ms/fr",
                  file=sys.stderr)
        out[level] = res_level
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", nargs="*", default=["moderate"])
    ap.add_argument("--methods", nargs="*", default=["klt_chain", "klt_key", "orb_key", "ecc_key"])
    ap.add_argument("--masks", nargs="*", default=["none", "lane", "lane_motion"])
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--no-blur", action="store_true")
    ap.add_argument("--tag", default=None)
    a = ap.parse_args()
    man = C.manifest()
    C.OUT.mkdir(exist_ok=True)
    results = {}
    for cid in LABELS:
        if a.only and cid not in a.only:
            continue
        results[cid] = run_clip(cid, man[cid], a.level, a.methods, a.masks, a.seed, blur=not a.no_blur)
    tag = a.tag or "_".join(a.level)
    (C.OUT / f"exp2_{tag}.json").write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
