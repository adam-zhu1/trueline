#!/usr/bin/env python3
"""Experiment 2d: does handheld motion and motion blur hurt ball detection?

    .venv/bin/python experiments/autocal_handheld/exp2_detector.py [--clips ...] [--variants ...]

Renders full-resolution copies of benchmark clips with simulated handheld
motion (handheld.Motion, 7-sample camera-motion blur over a 1/(2 fps)
exposure), encodes them with x264 (crf 14; the "still" variant is the same
encode with no motion, so codec loss cancels), and runs the app's own
ShotAnalyzer + Core ML detector on them through the accuracy benchmark's
Swift harness. The harness only knows the frame-0 corners, so:
  - tremor_* variants keep the lane where it was (tremor only, 0.15 or 0.3
    deg): a clean test of the detector under blur;
  - moderate / strong add the slow drift, so the fixed lane box and lane
    gate are partly wrong too (that is what a handheld app without
    per-frame calibration would do).
Detections are scored against the hand labels carried into the moving
frame (W_t applied to the label), and metrics are recomputed from the
detector boxes mapped back through the true W_t (so calibration error is
excluded), with the benchmark's label-metric rules.
Rendered videos go to the system temp dir and are deleted afterwards.
"""
import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import handheld as HH  # noqa: E402
from exp2_handheld import LABELS, label_metrics  # noqa: E402

TMP = Path(tempfile.gettempdir()) / "trueline_handheld"


def render_video(clip, level, n_frames, fps, path, seed=1):
    cap = cv2.VideoCapture(clip["video"])
    ok, fr = cap.read()
    h, w = fr.shape[:2]
    mo = HH.Motion(level, fps, w, h, seed=seed)
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24",
           "-s", f"{w}x{h}", "-r", str(fps), "-i", "-", "-c:v", "libx264", "-crf", "14",
           "-preset", "fast", "-pix_fmt", "yuv420p", str(path)]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    i = 0
    while ok and i < n_frames:
        out = HH.render(fr, mo, i / fps, 1 / (2 * fps), samples=7) if level != "still" else fr
        p.stdin.write(out.tobytes())
        i += 1
        ok, fr = cap.read()
    p.stdin.close()
    p.wait()
    cap.release()
    return mo


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips", nargs="*", default=["IMG_5108", "IMG_5113", "IMG_5115", "portfolio_30"])
    ap.add_argument("--variants", nargs="*", default=["still", "tremor_moderate", "tremor_strong", "moderate", "strong"])
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    TMP.mkdir(exist_ok=True)
    man = C.manifest()
    entries, motions = [], {}
    for cid in a.clips:
        clip = man[cid]
        fps = 60.0 if cid == "portfolio_60" else 30.0
        n = max(f["frame"] for f in LABELS[cid]["frames"]) + 30
        for v in a.variants:
            path = TMP / f"{cid}_{v}.mp4"
            print(f"render {cid} {v}", file=sys.stderr)
            motions[(cid, v)] = render_video(clip, v, n, fps, path)
            entries.append({**{k: clip[k] for k in ("hand", "farLeft", "farRight", "nearRight", "nearLeft")},
                            "id": f"{cid}|{v}", "video": str(path)})
    mpath = TMP / "manifest.json"
    mpath.write_text(json.dumps(entries))
    C.bench.build()
    outp = TMP / "out.json"
    subprocess.run([str(C.bench.BIN), str(mpath), str(outp), str(C.REPO / "ios/Trueline/Trueline/ML/ball.mlpackage")],
                   check=True, cwd=C.REPO)
    runs = {r["id"]: r for r in json.loads(outp.read_text())}
    results = {}
    for e in entries:
        cid, v = e["id"].split("|")
        r = runs[e["id"]]
        mo = motions[(cid, v)]
        fps = 60.0 if cid == "portfolio_60" else 30.0
        H0 = C.lane_to_image(C.corners_array(man[cid]))
        tr = C.bench.trace_display(r)
        lab = LABELS[cid]
        errs, hits = [], 0
        for f in lab["frames"]:
            i = int(f["frame"])
            W = mo.W(i / fps)
            q = C.project(W, [(f["x"], f["y"])])[0]
            s = tr.get(i)
            if s is not None and s["det"] is not None:
                d = math.hypot(s["det"][0] - q[0], s["det"][1] - q[1])
                errs.append(d)
                hits += d < f["r"]
        # metrics from the detector boxes, mapped through the true motion
        pts = []
        for i, s in sorted(tr.items()):
            if s["det"] is None:
                continue
            W = mo.W(i / fps)
            c = C.project(np.linalg.inv(W), [(s["det"][0], s["det"][1])])[0]
            # contact point: centre plus box radius straight down, in the original frame
            l = C.project(np.linalg.inv(H0), [(c[0], c[1] + s["detectionRadius"])])[0]
            pts.append((i / fps, l[0] * 39, l[1]))
        t = r.get("trace") or {}
        results[e["id"]] = {
            "tracked": r["trackedFrames"], "measured": t.get("measured"), "raw_boxes": t.get("rawBoxes"),
            "outside_lane": t.get("outsideLane"), "low_conf": t.get("lowConfNear"),
            "depth_ft": [t["samples"][0]["feet"], t["samples"][-1]["feet"]] if t.get("samples") else None,
            "labels": len(lab["frames"]), "label_hits": hits, "label_det": len(errs),
            "det_err_px_median": float(np.median(errs)) if errs else None,
            "app_entry": r.get("entryBoard"), "app_speed": r.get("speedMph"),
            "box_metrics": label_metrics(pts) if len(pts) > 5 else None,
        }
        print(e["id"], results[e["id"]], file=sys.stderr)
    (C.OUT / "exp2_detector.json").write_text(json.dumps(results, indent=1))
    if not a.keep:
        for e in entries:
            os.remove(e["video"])


if __name__ == "__main__":
    main()
