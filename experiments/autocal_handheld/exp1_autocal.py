#!/usr/bin/env python3
"""Experiment 1: automatic lane calibration on the calibrated benchmark clips.

    .venv/bin/python experiments/autocal_handheld/exp1_autocal.py [--overlays]

(a) the existing detector: the Swift LaneAutoDetector (the app's code, built
    with experiments/lane_autodetect_swift/main.swift) and the Python
    prototype it was ported from;
(b) lanefit.py, the feature-based fit, in three depth modes;
scored against the benchmark calibrations: corner px error and board error
across the lane at the arrows (15 ft) and the pins (59.5 ft). The landmark
files from calibration_v11 give per-feature truth (arrow marks, head pin,
foul corners) for the feature reliability table.
Writes out/exp1.json and prints markdown tables.
"""
import argparse
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import lanefit  # noqa: E402

sys.path.insert(0, str(C.REPO / "experiments"))
import lane_autodetect as proto  # noqa: E402

TMP = Path(tempfile.gettempdir()) / "trueline_autocal"


def swift_detect(frames):
    binp = TMP / "lanedetect"
    if not binp.exists():
        subprocess.run(["swiftc", "-O", "-o", str(binp), "experiments/lane_autodetect_swift/main.swift",
                        "ios/Trueline/Trueline/Analysis/LaneAutoDetector.swift",
                        "ios/Trueline/Trueline/Models/LaneCorners.swift"], check=True, cwd=C.REPO)
    out = subprocess.run([str(binp), *map(str, frames)], capture_output=True, text=True).stdout
    res = {}
    for line in out.splitlines():
        parts = line.split()
        name = parts[1].rsplit("_f0", 1)[0]
        if parts[0] != "OK":
            res[name] = None
            continue
        nums = [float(v) for v in line.replace("(", " ").replace(")", " ").replace(",", " ").split()
                if v.replace(".", "").replace("-", "").isdigit()]
        fl, fr, pl, pr = (nums[0:2], nums[2:4], nums[4:6], nums[6:8])
        res[name] = [fr, fl, pl, pr]   # nearRight, nearLeft, farLeft, farRight
    return res


def proto_detect(frame):
    c, _ = proto.detect_corners(frame)
    if c is None:
        return None
    return [c["foul_line_right"], c["foul_line_left"], c["pin_line_left"], c["pin_line_right"]]


def feature_truth(cid, clip):
    """Per-feature truth in display px: hand landmarks where they exist,
    else the calibration's own projection."""
    lm = C.landmarks(cid)
    H = C.lane_to_image(C.corners_array(clip))
    t = {"foul": C.project(H, [(0, 0), (1, 0)]).tolist(),
         "headpin": C.project(H, [(0.5, 60)])[0].tolist(),
         "arrows": None}
    if lm:
        t["arrows"] = lm["arrows"]          # ordered left to right on screen
        t["headpin"] = lm["headpin"]
    return t


def draw(frame, true_c, est_c, rep, path):
    vis = frame.copy()
    cv2.polylines(vis, [np.int32(true_c)], True, (0, 255, 0), 3)
    if est_c is not None:
        cv2.polylines(vis, [np.int32(est_c)], True, (0, 0, 255), 3)
        for p in rep.get("arrows_px", []):
            cv2.circle(vis, (int(p[0]), int(p[1])), 6, (255, 0, 255), 2)
        hp = rep.get("headpin_px")
        if hp:
            cv2.circle(vis, (int(hp[0]), int(hp[1])), 6, (255, 255, 0), 2)
    cv2.imwrite(str(path), vis)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--overlays", action="store_true")
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--stability", action="store_true", help="also run on other frames of each clip")
    ap.add_argument("--report-only", action="store_true", help="re-print tables from out/exp1.json")
    a = ap.parse_args()
    if a.report_only:
        report(json.loads((C.OUT / "exp1.json").read_text()))
        if a.stability:
            stability()
        return
    TMP.mkdir(exist_ok=True)
    C.OUT.mkdir(exist_ok=True)
    man = C.manifest()
    ids = [i for i in man if not a.only or i in a.only]
    frames = {}
    for cid in ids:
        fr = C.read_frame(man[cid]["video"], 0)
        p = TMP / f"{cid}_f0.png"
        cv2.imwrite(str(p), fr)
        frames[cid] = (fr, p)
    sw = swift_detect([frames[c][1] for c in ids])
    results = {}
    for cid in ids:
        fr, _ = frames[cid]
        true_c = C.corners_array(man[cid])
        row = {}
        for name, est in (("swift", sw.get(cid)), ("proto", proto_detect(fr))):
            row[name] = C.calib_errors(true_c, est) if est is not None else None
            if est is not None:
                row[name]["corners"] = np.asarray(est).tolist()
        t0 = time.time()
        allfits, base_rep = lanefit.detect(fr, mode="all")
        dt = time.time() - t0
        for mode in ("arrows", "pins", "joint", "refined"):
            est, rep = (None, base_rep) if allfits is None else (allfits[mode][0], {**base_rep, **allfits[mode][1]})
            r = {"report": rep, "seconds": dt}
            if est is not None:
                r.update(C.calib_errors(true_c, est))
                r["corners"] = est.tolist()
                ft = feature_truth(cid, man[cid])
                r["foul_px_err"] = float(np.mean(np.linalg.norm(np.array(rep["foul_px"]) - np.array(ft["foul"]), axis=1)))
                r["headpin_px_err"] = float(np.linalg.norm(np.array(rep["headpin_px"]) - np.array(ft["headpin"])))
                if ft["arrows"] is not None:
                    pa = np.array(rep["arrows_px"])
                    ta = np.array(sorted(ft["arrows"], key=lambda p: p[0]))
                    pa = pa[np.argsort(pa[:, 0])]
                    r["arrows_px_err"] = float(np.mean(np.linalg.norm(pa - ta, axis=1)))
                lm = C.landmarks(cid)
                if lm:
                    # hand-picked pin columns (image x of each visible pin at
                    # its base) read back through this calibration, in boards
                    pc = np.array(lm["pin_columns"])
                    back = C.project(np.linalg.inv(C.lane_to_image(est)), pc[:, :2])
                    r["pincol_board_err"] = float(np.mean(np.abs(back[:, 0] * 39 - (pc[:, 2] - 0.5))))
                if a.overlays and mode == "refined":
                    draw(fr, true_c, est, rep, C.OUT / f"exp1_{cid}.jpg")
            row[mode] = r
        results[cid] = row
        print(cid, {k: (None if v is None else round(v.get("pins_board_mean", -1), 2)) for k, v in row.items()},
              file=sys.stderr)
    (C.OUT / "exp1.json").write_text(json.dumps(results, indent=1, default=float))
    report(results)
    if a.stability:
        stability()


def report(results):
    f = C.fmt
    print("\n#### (a) Existing auto-detector\n")
    print("| Clip | Swift: corner px mean / max | arrows bd mean / max | pins bd mean / max | Python proto: corner px | pins bd mean |")
    print("|---|---|---|---|---|---|")
    for cid, r in results.items():
        s, p = r["swift"], r["proto"]
        cs = "no proposal" if s is None else f"{f(s['corner_px_mean'], 0)} / {f(s['corner_px_max'], 0)}"
        a = "--" if s is None else f"{f(s['arrows_board_mean'])} / {f(s['arrows_board_max'])}"
        pn = "--" if s is None else f"{f(s['pins_board_mean'])} / {f(s['pins_board_max'])}"
        pc = "no proposal" if p is None else f(p["corner_px_mean"], 0)
        pp = "--" if p is None else f(p["pins_board_mean"])
        print(f"| {cid} | {cs} | {a} | {pn} | {pc} | {pp} |")
    for mode in ("arrows", "pins", "joint", "refined"):
        print(f"\n#### (b) Feature fit, depth from {mode}\n")
        print("| Clip | corner px mean / max | arrows bd mean / max | pins bd mean / max | pins feet | foul px | arrows px | headpin px | pin cols bd |")
        print("|---|---|---|---|---|---|---|---|---|")
        agg = []
        for cid, r in results.items():
            m = r[mode]
            if "corners" not in m:
                print(f"| {cid} | failed ({m['report'].get('fail')}) | | | | | | |")
                continue
            agg.append([m["corner_px_mean"], m["arrows_board_mean"], m["pins_board_mean"]])
            print(f"| {cid} | {f(m['corner_px_mean'], 0)} / {f(m['corner_px_max'], 0)} "
                  f"| {f(m['arrows_board_mean'])} / {f(m['arrows_board_max'])} "
                  f"| {f(m['pins_board_mean'])} / {f(m['pins_board_max'])} | {m['pins_feet']:+.1f} "
                  f"| {f(m['foul_px_err'], 0)} | {f(m.get('arrows_px_err'), 0)} | {f(m["headpin_px_err"], 0)} | {f(m.get("pincol_board_err"))} |")
        if agg:
            g = np.array(agg)
            print(f"| median | {np.median(g[:, 0]):.0f} | {np.median(g[:, 1]):.1f} | {np.median(g[:, 2]):.1f} | | | | |")
    label_check(results)


def stability(mode="refined"):
    """The same proposal on several frames of each clip: four frames before
    the throw (frames 0, 30, 60, 90) and one with the bowler and ball in view
    (the first labelled frame, or frame 40 of the portfolio throw)."""
    import exp2_handheld as E2
    man = C.manifest()
    print(f"\n#### Proposal on other frames ({mode})\n")
    print("| Clip | pins bd mean, frames 0/30/60/90 | spread of corners px (max) | frame with bowler: pins bd | corner px |")
    print("|---|---|---|---|---|")
    for cid, clip in man.items():
        true_c = C.corners_array(clip)
        ests, pins = [], []
        for fi in (0, 30, 60, 90):
            fr = C.read_frame(clip["video"], fi)
            out, _ = lanefit.detect(fr, mode="all")
            if out is None:
                pins.append(None)
                continue
            ests.append(out[mode][0])
            pins.append(C.calib_errors(true_c, out[mode][0])["pins_board_mean"])
        spread = max(np.linalg.norm(e - np.mean(ests, 0), axis=1).max() for e in ests) if ests else None
        bf = E2.LABELS[cid]["frames"][0]["frame"] if cid in E2.LABELS else 40
        out, rep = lanefit.detect(C.read_frame(clip["video"], int(bf)), mode="all")
        e = C.calib_errors(true_c, out[mode][0]) if out else None
        print(f"| {cid} | {' / '.join(C.fmt(p) for p in pins)} | {C.fmt(spread)} "
              f"| {C.fmt(e and e['pins_board_mean'])} (frame {int(bf)}) | {C.fmt(e and e['corner_px_mean'], 0)} |")


def label_check(results, mode="refined"):
    """Which depth is right where the two calibrations disagree? Map the hand
    labelled balls through both and look at the ball's speed by lane zone
    (a real ball slows down 10-15% from release to the pins) and at the
    label-only entry board (bench rules: quadratic over 45+ ft at 59.5 ft)."""
    import exp2_handheld as E2
    man = C.manifest()
    print(f"\n#### Labelled balls through the reference vs the {mode} proposal\n")
    print("| Clip | speed 0-20 / 20-40 / 40-58 ft, reference | same, proposal | entry reference / proposal | last label ft, reference / proposal |")
    print("|---|---|---|---|---|")
    for cid, lab in E2.LABELS.items():
        if cid not in results or "corners" not in results[cid][mode]:
            continue
        fps = 30.0
        cals = {"ref": C.corners_array(man[cid]), "auto": np.array(results[cid][mode]["corners"])}
        mapped = {}
        for k, c in cals.items():
            Hi = np.linalg.inv(C.lane_to_image(c))
            mapped[k] = np.array([(fr["frame"] / fps, *C.project(Hi, [(fr["x"], fr["y"] + fr["r"])])[0])
                                  for fr in lab["frames"]])
        zones = {}
        for lo, hi in ((0, 20), (20, 40), (40, 58)):
            zones[(lo, hi)] = (mapped["ref"][:, 2] >= lo) & (mapped["ref"][:, 2] < hi)   # same samples for both
        cells = []
        for k in ("ref", "auto"):
            sp = []
            for m in zones.values():
                sp.append(np.polyfit(mapped[k][m, 0], mapped[k][m, 2], 1)[0] * 0.681818 if m.sum() >= 3 else None)
            cells.append(" / ".join(C.fmt(v) for v in sp))
        ent = []
        for k in ("ref", "auto"):
            pts = [(t, x * 39, ft) for t, x, ft in mapped[k]]
            ent.append(E2.label_metrics(pts)["entry"])
        print(f"| {cid} | {cells[0]} | {cells[1]} | {C.fmt(ent[0])} / {C.fmt(ent[1])} "
              f"| {mapped['ref'][:, 2].max():.1f} / {mapped['auto'][:, 2].max():.1f} |")


if __name__ == "__main__":
    main()
