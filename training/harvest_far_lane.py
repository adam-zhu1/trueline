#!/usr/bin/env python3
"""
Harvest hard training frames for the back end of the lane (trajectory-gated
pseudo-labeling), plus hard negatives.

Why auto_label.py is not enough
-------------------------------
auto_label.py keeps only detections the model is already confident about
(conf >= 0.5). Past ~45 ft the ball is small/blurry and scores low, so the
frames we most need never make it into the dataset — the model can't teach
itself what it can't see.

What this script does instead
-----------------------------
1. Detect on EVERY frame at a very low floor (default 0.08), keep in-lane boxes.
2. Confident detections (>= --anchor-conf) form "anchor" trajectories per shot
   (a video may contain several shots).
3. Between and beyond anchors, the expected ball position is predicted in LANE
   coordinates (t_across, feet) — linear in feet-per-frame, which stays valid in
   the back end where perspective compresses 12 ft of lane into a few pixels —
   then mapped back to pixels through the calibration homography.
4. A low-confidence detection within a tight pixel gate of the prediction is
   almost certainly the real ball: save it as a training label. These are
   exactly the small/blurred far-lane examples the dataset lacks.
5. Hard negatives: frames far away from any shot with NO detection anywhere in
   the frame (not just the lane) are saved with empty labels — pin deck at
   rest, lane shine, machine motion.

Usage (repo root, .venv active; calibration must match the video):
  python3 training/harvest_far_lane.py --video "data/ScreenRecording_06-10-2026 15-50-00_1.MP4"
  python3 training/harvest_far_lane.py --video ... --dry-run   # report only

Then delete label caches and retrain exactly as in training/README.md.
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from ball_tracking import _image_to_lane_H  # noqa: E402
from calibration import detection_center_in_lane  # noqa: E402

IMAGES_TRAIN = Path("dataset/ball_yolo/images/train")
IMAGES_VAL = Path("dataset/ball_yolo/images/val")
LABELS_TRAIN = Path("dataset/ball_yolo/labels/train")
LABELS_VAL = Path("dataset/ball_yolo/labels/val")
BALL_CLASS = 0


def _prefix_from_path(video_path: Path) -> str:
    import hashlib

    stem = video_path.stem.lower()
    clean = re.sub(r"[^a-z0-9]+", "_", stem).strip("_")
    # Long screen-recording names truncate identically; a short hash of the full
    # stem keeps prefixes unique per video so runs don't overwrite each other.
    tag = hashlib.sha1(stem.encode()).hexdigest()[:4]
    return ("far_" + clean)[:19] + "_" + tag


def _to_yolo_label(x1, y1, x2, y2, img_w, img_h) -> str:
    cx = ((x1 + x2) / 2) / img_w
    cy = ((y1 + y2) / 2) / img_h
    w = (x2 - x1) / img_w
    h = (y2 - y1) / img_h
    vals = [max(0.0, min(1.0, v)) for v in (cx, cy, w, h)]
    return f"{BALL_CLASS} {vals[0]:.6f} {vals[1]:.6f} {vals[2]:.6f} {vals[3]:.6f}"


class Det:
    __slots__ = ("conf", "t", "feet", "cx", "cy", "r", "box")

    def __init__(self, conf, t, feet, cx, cy, r, box):
        self.conf, self.t, self.feet = conf, t, feet
        self.cx, self.cy, self.r = cx, cy, r
        self.box = box  # (x1, y1, x2, y2)


def collect(video_path: Path, model_path: Path, calibration: dict, floor: float):
    """Returns (per_frame_inlane, frames_with_any_detection, n_frames)."""
    from ultralytics import YOLO

    H = _image_to_lane_H(calibration)
    model = YOLO(str(model_path))
    cap = cv2.VideoCapture(str(video_path))
    per_frame: list[list[Det]] = []
    any_det: set[int] = set()
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        r0 = model.predict(source=frame, conf=floor, iou=0.45, verbose=False)[0]
        dets: list[Det] = []
        if r0.boxes is not None and len(r0.boxes):
            any_det.add(i)
            xyxy = r0.boxes.xyxy.cpu().numpy()
            confs = r0.boxes.conf.cpu().numpy()
            for (x1, y1, x2, y2), c in zip(xyxy, confs):
                cx, cy = 0.5 * (x1 + x2), 0.5 * (y1 + y2)
                if not detection_center_in_lane(cx, cy, calibration):
                    continue
                r = 0.5 * float(min(x2 - x1, y2 - y1))
                pt = np.array([[[cx, cy + r]]], dtype=np.float32)
                t_ac, feet = cv2.perspectiveTransform(pt, H)[0, 0]
                dets.append(Det(float(c), float(t_ac), float(feet),
                                float(cx), float(cy), r,
                                (float(x1), float(y1), float(x2), float(y2))))
        per_frame.append(dets)
        i += 1
    cap.release()
    return per_frame, any_det, i


def segment_shots(per_frame, anchor_conf):
    """Runs of confident, advancing detections: list of [(frame, Det), ...]."""
    anchors = []
    for i, dets in enumerate(per_frame):
        good = [d for d in dets if d.conf >= anchor_conf and -0.5 <= d.feet <= 56.0]
        if good:
            anchors.append((i, max(good, key=lambda d: d.conf)))
    shots, cur = [], []
    for fr, d in anchors:
        if cur and (fr - cur[-1][0] > 50 or d.feet < cur[-1][1].feet - 2.0):
            shots.append(cur)
            cur = []
        cur.append((fr, d))
    if cur:
        shots.append(cur)
    return [s for s in shots if len(s) >= 8 and s[-1][1].feet - s[0][1].feet >= 15.0]


def follow_shot(shot, per_frame, calibration, gate_scale=1.8, max_miss=30):
    """
    Walk the shot frame by frame. Anchors are truth; in gaps and past the last
    anchor, predict (t, feet) from the recent accepted trend and accept the best
    gated low-conf detection. Returns list of (frame, Det, is_anchor).
    """
    H_inv = np.linalg.inv(_image_to_lane_H(calibration))
    anchor_by_frame = dict(shot)
    accepted: list[tuple[int, Det, bool]] = []
    recent: list[tuple[int, float, float, float]] = []  # frame, t, feet, r

    def predict(frame):
        pts = recent[-12:]
        fr = np.array([p[0] for p in pts], dtype=np.float64)
        if len(pts) >= 3 and np.ptp(fr) > 0:
            a_f, b_f = np.polyfit(fr, [p[2] for p in pts], 1)
            a_t, b_t = np.polyfit(fr, [p[1] for p in pts], 1)
            return a_t * frame + b_t, a_f * frame + b_f
        return pts[-1][1], pts[-1][2]

    start, end = shot[0][0], len(per_frame) - 1
    misses = 0
    for fr in range(start, end + 1):
        if fr in anchor_by_frame:
            d = anchor_by_frame[fr]
            accepted.append((fr, d, True))
            recent.append((fr, d.t, d.feet, d.r))
            misses = 0
            continue
        if not recent:
            continue
        t_pred, feet_pred = predict(fr)
        if feet_pred > 60.5:
            break
        pt = np.array([[[t_pred, feet_pred]]], dtype=np.float32)
        px, py = cv2.perspectiveTransform(pt, H_inv)[0, 0]
        med_r = float(np.median([p[3] for p in recent[-8:]]))
        gate = max(22.0, gate_scale * med_r)
        cands = [d for d in per_frame[fr]
                 if np.hypot(d.cx - px, (d.cy + d.r) - py) <= gate]
        if cands:
            d = max(cands, key=lambda d: d.conf)
            accepted.append((fr, d, False))
            recent.append((fr, d.t, d.feet, d.r))
            misses = 0
        else:
            misses += 1
            if misses > max_miss:
                break

    # Backward pass toward the release: anchors rarely cover the first feet
    # (motion blur, body occlusion), which is exactly where the speed timing
    # needs measurements. Same gating, walking the other way.
    early: list[tuple[int, float, float, float]] = \
        [(fr, d.t, d.feet, d.r) for fr, d, _ in accepted[:12]]
    misses = 0
    for fr in range(start - 1, max(-1, start - 240), -1):
        pts = early[:12]
        fr_arr = np.array([p[0] for p in pts], dtype=np.float64)
        if len(pts) >= 3 and np.ptp(fr_arr) > 0:
            a_f, b_f = np.polyfit(fr_arr, [p[2] for p in pts], 1)
            a_t, b_t = np.polyfit(fr_arr, [p[1] for p in pts], 1)
            t_pred, feet_pred = a_t * fr + b_t, a_f * fr + b_f
        else:
            t_pred, feet_pred = pts[0][1], pts[0][2]
        if feet_pred < -2.0:
            break
        pt = np.array([[[t_pred, feet_pred]]], dtype=np.float32)
        px, py = cv2.perspectiveTransform(pt, H_inv)[0, 0]
        med_r = float(np.median([p[3] for p in early[:8]]))
        gate = max(22.0, gate_scale * med_r)
        cands = [d for d in per_frame[fr]
                 if np.hypot(d.cx - px, (d.cy + d.r) - py) <= gate]
        if cands:
            d = max(cands, key=lambda d: d.conf)
            accepted.append((fr, d, d.conf >= 0.50))
            early.insert(0, (fr, d.t, d.feet, d.r))
            misses = 0
        else:
            misses += 1
            if misses > max_miss:
                break
    accepted.sort(key=lambda a: a[0])
    return accepted


def main() -> None:
    p = argparse.ArgumentParser(description="Trajectory-gated far-lane pseudo-labeling")
    p.add_argument("--video", "-v", type=Path, required=True)
    p.add_argument("--model", "-m", type=Path, default=Path("models/ball.pt"))
    p.add_argument("--calibration", type=Path, default=Path("data/calibration.json"))
    p.add_argument("--floor-conf", type=float, default=0.08)
    p.add_argument("--anchor-conf", type=float, default=0.50)
    p.add_argument("--far-feet", type=float, default=38.0,
                   help="Anchors past this distance are saved too (far positives are scarce)")
    p.add_argument("--stride", type=int, default=2,
                   help="Save every Nth harvested frame (consecutive frames are near-duplicates)")
    p.add_argument("--negatives", type=int, default=8, help="Max hard negatives per video")
    p.add_argument("--val-split", type=float, default=0.15)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if not args.video.is_file():
        raise SystemExit(f"Video not found: {args.video}")
    calibration = json.loads(args.calibration.read_text())
    prefix = _prefix_from_path(args.video)
    random.seed(42)

    print(f"Video  : {args.video}")
    print(f"Model  : {args.model}")
    print(f"Prefix : {prefix}_")
    if args.dry_run:
        print("DRY RUN — no files will be written")
    print("\nDetecting on every frame (low floor)…")
    per_frame, any_det, n_frames = collect(args.video, args.model, calibration, args.floor_conf)
    shots = segment_shots(per_frame, args.anchor_conf)
    print(f"  {n_frames} frames, {len(shots)} shot(s) found")

    # --- positives: gated low-conf accepts + far-lane anchors ---
    to_save: dict[int, Det] = {}
    shot_frames: set[int] = set()
    for k, shot in enumerate(shots):
        accepted = follow_shot(shot, per_frame, calibration)
        shot_frames.update(fr for fr, _, _ in accepted)
        shot_frames.update(fr for fr, _ in shot)
        gap_accepts = [(fr, d) for fr, d, is_anchor in accepted if not is_anchor]
        far_anchors = [(fr, d) for fr, d, is_anchor in accepted
                       if is_anchor and d.feet >= args.far_feet]
        last_ft = accepted[-1][1].feet if accepted else float("nan")
        print(f"  shot {k + 1}: frames {shot[0][0]}-{accepted[-1][0] if accepted else '?'}, "
              f"{len(shot)} anchors, {len(gap_accepts)} gated low-conf accepts, "
              f"{len(far_anchors)} far anchors, reached {last_ft:.1f} ft")
        for fr, d in sorted(gap_accepts + far_anchors):
            to_save[fr] = d
    keep_frames = sorted(to_save)[:: max(1, args.stride)]

    # --- hard negatives: far from shots, nothing detected anywhere in frame ---
    margin = 60
    near_shot = set()
    for fr in shot_frames:
        near_shot.update(range(fr - margin, fr + margin + 1))
    neg_pool = [i for i in range(n_frames) if i not in near_shot and i not in any_det]
    neg_frames = neg_pool[:: max(1, len(neg_pool) // args.negatives)][: args.negatives] \
        if neg_pool else []

    print(f"\n  positives to save : {len(keep_frames)} (stride {args.stride})")
    feet_hist = [to_save[fr].feet for fr in keep_frames]
    if feet_hist:
        for lo in range(0, 60, 10):
            n = sum(1 for f in feet_hist if lo <= f < lo + 10)
            if n:
                print(f"    {lo:>2d}-{lo + 10:<2d} ft: {n}")
    print(f"  hard negatives    : {len(neg_frames)} (pool {len(neg_pool)})")

    if args.dry_run:
        return

    for d in (IMAGES_TRAIN, IMAGES_VAL, LABELS_TRAIN, LABELS_VAL):
        d.mkdir(parents=True, exist_ok=True)

    # second pass over the video to write the chosen frames
    wanted = {fr: to_save.get(fr) for fr in keep_frames}
    for fr in neg_frames:
        wanted.setdefault(fr, None)
    cap = cv2.VideoCapture(str(args.video))
    saved_pos = saved_neg = 0
    fr = 0
    while wanted:
        ok, frame = cap.read()
        if not ok:
            break
        if fr in wanted:
            det = wanted.pop(fr)
            go_val = random.random() < args.val_split
            img_dir = IMAGES_VAL if go_val else IMAGES_TRAIN
            lbl_dir = LABELS_VAL if go_val else LABELS_TRAIN
            # Name by source frame number: re-running on the same video (e.g. with a
            # better model) overwrites identical frames instead of duplicating them.
            name = f"{prefix}_{fr:05d}"
            if (IMAGES_TRAIN / f"{name}.jpg").exists() or (IMAGES_VAL / f"{name}.jpg").exists():
                fr += 1
                continue
            cv2.imwrite(str(img_dir / f"{name}.jpg"), frame)
            if det is None:
                (lbl_dir / f"{name}.txt").write_text("")
                saved_neg += 1
            else:
                x1, y1, x2, y2 = det.box
                line = _to_yolo_label(x1, y1, x2, y2, frame.shape[1], frame.shape[0])
                (lbl_dir / f"{name}.txt").write_text(line + "\n")
                saved_pos += 1
        fr += 1
    cap.release()
    print(f"\nSaved {saved_pos} positives + {saved_neg} negatives as {prefix}_*.jpg")
    print("Next: rm -f dataset/ball_yolo/labels/train.cache dataset/ball_yolo/labels/val.cache")


if __name__ == "__main__":
    main()
