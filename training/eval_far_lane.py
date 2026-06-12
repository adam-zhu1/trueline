#!/usr/bin/env python3
"""
Measure ball-detection recall down the lane, with emphasis on the back end (40-60 ft).

Why this exists
---------------
Tracking degrades past ~45 ft because the detector misses the small/blurry ball.
Before and after retraining we need a number, not an impression. There is no
hand-labeled ground truth, so this script builds its own reference trajectory:

1. Run the model on EVERY frame at a low confidence floor; keep in-lane boxes.
2. "Anchors" = confident detections (conf >= --anchor-conf) in the 2-40 ft range,
   where the current model is reliable.
3. Fit feet-vs-frame linearly over the anchors and extrapolate to 60 ft. That
   predicts WHEN the ball should be at every distance, including the back end.
4. For each frame in the predicted window, recall = was there an in-lane
   detection (at a given conf threshold) within --feet-tol of the predicted feet?

Reported per 10 ft bin and per confidence threshold, e.g.:

  python3 training/eval_far_lane.py --video "data/ScreenRecording_06-10-2026 15-50-00_1.MP4"

Run from the repo root with .venv active. Calibration must match the video's
camera setup (same check as the app itself).
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import cv2
import numpy as np

# src/ imports (image_to_lane, lane test) without packaging changes
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from ball_tracking import image_to_lane  # noqa: E402
from calibration import detection_center_in_lane  # noqa: E402

DEFAULT_CONFS = (0.35, 0.25, 0.15)
BINS = ((0, 10), (10, 20), (20, 30), (30, 40), (40, 45), (45, 50), (50, 55), (55, 60))


def collect_detections(video_path: Path, model_path: Path, calibration: dict,
                       floor_conf: float, imgsz: int | None):
    """Per frame: list of (conf, feet, cx, cy) for in-lane boxes above floor_conf."""
    from ultralytics import YOLO

    model = YOLO(str(model_path))
    cap = cv2.VideoCapture(str(video_path))
    per_frame = []
    t0 = time.time()
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        kwargs = dict(source=frame, conf=floor_conf, iou=0.45, verbose=False)
        if imgsz:
            kwargs["imgsz"] = imgsz
        r0 = model.predict(**kwargs)[0]
        dets = []
        if r0.boxes is not None and len(r0.boxes):
            xyxy = r0.boxes.xyxy.cpu().numpy()
            confs = r0.boxes.conf.cpu().numpy()
            for (x1, y1, x2, y2), c in zip(xyxy, confs):
                cx, cy = 0.5 * (x1 + x2), 0.5 * (y1 + y2)
                if not detection_center_in_lane(cx, cy, calibration):
                    continue
                r = 0.5 * float(min(x2 - x1, y2 - y1))
                _, feet = image_to_lane(cx, cy + r, calibration)
                if feet is None:
                    continue
                dets.append((float(c), float(feet), float(cx), float(cy)))
        per_frame.append(dets)
    cap.release()
    n = len(per_frame)
    dt = time.time() - t0
    print(f"  {n} frames, {dt:.1f}s total ({1000 * dt / max(n, 1):.1f} ms/frame incl. video IO)")
    return per_frame


def fit_reference(per_frame, anchor_conf: float):
    """Linear feet(frame) fit over confident 2-40 ft detections. None if too few."""
    frames, feet = [], []
    for i, dets in enumerate(per_frame):
        if not dets:
            continue
        c, f, _, _ = max(dets, key=lambda d: d[0])
        if c >= anchor_conf and 2.0 <= f <= 40.0:
            frames.append(i)
            feet.append(f)
    if len(frames) < 5:
        return None, 0
    a, b = np.polyfit(np.array(frames, dtype=np.float64),
                      np.array(feet, dtype=np.float64), 1)
    if a <= 1e-6:  # ball must move toward the pins
        return None, len(frames)
    return (a, b), len(frames)


def main() -> None:
    p = argparse.ArgumentParser(description="Far-lane detection recall (no ground truth needed)")
    p.add_argument("--video", "-v", type=Path, required=True, action="append",
                   help="Video path (repeatable)")
    p.add_argument("--model", "-m", type=Path, default=Path("models/ball.pt"))
    p.add_argument("--calibration", type=Path, default=Path("data/calibration.json"))
    p.add_argument("--confs", type=float, nargs="+", default=list(DEFAULT_CONFS),
                   help="Confidence thresholds to report recall at")
    p.add_argument("--anchor-conf", type=float, default=0.50)
    p.add_argument("--feet-tol", type=float, default=8.0,
                   help="Detection counts as a hit if |feet - predicted feet| <= this")
    p.add_argument("--imgsz", type=int, default=0, help="Inference imgsz (0 = model default)")
    args = p.parse_args()

    calibration = json.loads(args.calibration.read_text())
    floor = min(min(args.confs), 0.10)

    totals = {c: {b: [0, 0] for b in BINS} for c in args.confs}  # [hits, frames]

    for video in args.video:
        print(f"\n=== {video.name} ===")
        per_frame = collect_detections(video, args.model, calibration, floor, args.imgsz or None)
        fit, n_anchors = fit_reference(per_frame, args.anchor_conf)
        if fit is None:
            print(f"  SKIP: only {n_anchors} anchors with conf>={args.anchor_conf} in 2-40 ft")
            continue
        a, b = fit
        print(f"  reference: feet = {a:.3f}*frame + {b:.1f}  ({n_anchors} anchors)")

        for i, dets in enumerate(per_frame):
            pred_feet = a * i + b
            if pred_feet < 0.0 or pred_feet > 60.0:
                continue
            for lo, hi in BINS:
                if lo <= pred_feet < hi or (hi == 60 and pred_feet == 60.0):
                    bin_key = (lo, hi)
                    break
            else:
                continue
            for c in args.confs:
                totals[c][bin_key][1] += 1
                hit = any(dc >= c and abs(df - pred_feet) <= args.feet_tol
                          for dc, df, _, _ in dets)
                if hit:
                    totals[c][bin_key][0] += 1

    print("\n========== RECALL BY DISTANCE (all videos) ==========")
    header = "  bin (ft)   " + "".join(f"conf>={c:<6.2f}" for c in args.confs) + "frames"
    print(header)
    for bin_key in BINS:
        lo, hi = bin_key
        row = f"  {lo:>2d}-{hi:<2d}      "
        n = totals[args.confs[0]][bin_key][1]
        for c in args.confs:
            h, tot = totals[c][bin_key]
            row += f"{(100.0 * h / tot if tot else float('nan')):>7.1f}%    " if tot else "     --     "
        row += f"{n:>5d}"
        print(row)


if __name__ == "__main__":
    main()
