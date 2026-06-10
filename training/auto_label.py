#!/usr/bin/env python3
"""
Auto-label bowling ball frames using the existing ball.pt model (pseudo-labeling).

What pseudo-labeling means
--------------------------
We already have a trained model (ball.pt). It's not perfect, but when it's
*very* confident about a detection it's almost always right. So we run it on
new videos, keep only the high-confidence frames, and save those as new
training examples. More data → retrain → better model → even more data next run.

Why high confidence matters
---------------------------
If we kept every detection (even shaky 30% ones), we'd be training on wrong
boxes and making the model worse. Using a high threshold (default 0.5) means
we only keep cases the model is already sure about, which are almost always
correct bounding boxes.

Why we sample frames instead of taking every one
-------------------------------------------------
A bowling shot is ~2 seconds at 60fps = 120 nearly-identical frames. Training
on 120 copies of the same image teaches the model nothing new and wastes time.
Sampling at 3fps gives us ~6 diverse frames per shot with very little overlap.

Run from the project root:
  python3 training/auto_label.py --video data/phaze-ii.mov
  python3 training/auto_label.py --video data/the-hype.mov
  python3 training/auto_label.py --video "data/ScreenRecording_03-30-2026 15-05-02_1.MP4"

After running on all your videos, retrain:
  python3 training/train_ball_detector.py \\
    --data dataset/ball_yolo/data.yaml \\
    --model models/ball.pt --epochs 80
"""

import argparse
import random
import re
from pathlib import Path

import cv2
from ultralytics import YOLO

# Where labeled frames are stored (YOLO dataset layout)
IMAGES_TRAIN = Path("dataset/ball_yolo/images/train")
IMAGES_VAL   = Path("dataset/ball_yolo/images/val")
LABELS_TRAIN = Path("dataset/ball_yolo/labels/train")
LABELS_VAL   = Path("dataset/ball_yolo/labels/val")

# YOLO class index for bowling_ball (must match data.yaml)
BALL_CLASS = 0


def _prefix_from_path(video_path: Path) -> str:
    """
    Turn a video filename into a short, filesystem-safe prefix for saved frames.
    e.g. "phaze-ii.mov" → "phaze_ii"
         "ScreenRecording_03-30-2026 15-05-02_1.MP4" → "screenrecording_03_30_2026"
    We truncate to 24 chars so filenames stay readable.
    """
    stem = video_path.stem.lower()
    # Replace anything that isn't a letter or digit with an underscore
    clean = re.sub(r"[^a-z0-9]+", "_", stem).strip("_")
    return clean[:24]


def _to_yolo_label(x1: float, y1: float, x2: float, y2: float,
                   img_w: int, img_h: int) -> str:
    """
    Convert a pixel bounding box (x1,y1,x2,y2) to a YOLO label line.

    YOLO format: <class> <cx> <cy> <w> <h>
    All four values are normalized to [0, 1] relative to the image size.
    For example, a box in the center of a 640x480 image would be:
      0  0.5  0.5  <box_w/640>  <box_h/480>
    """
    cx = ((x1 + x2) / 2) / img_w
    cy = ((y1 + y2) / 2) / img_h
    w  = (x2 - x1) / img_w
    h  = (y2 - y1) / img_h
    # Clamp to valid range just in case of tiny float drift
    cx = max(0.0, min(1.0, cx))
    cy = max(0.0, min(1.0, cy))
    w  = max(0.0, min(1.0, w))
    h  = max(0.0, min(1.0, h))
    return f"{BALL_CLASS} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}"


def run(video_path: Path, model_path: Path, conf: float,
        fps: float, val_fraction: float, dry_run: bool) -> None:

    # ------------------------------------------------------------------ #
    # 1. Sanity checks
    # ------------------------------------------------------------------ #
    if not video_path.is_file():
        raise SystemExit(f"Video not found: {video_path}")
    if not model_path.is_file():
        raise SystemExit(f"Model not found: {model_path}  (run train first)")

    # Create output folders if they don't exist yet
    for d in (IMAGES_TRAIN, IMAGES_VAL, LABELS_TRAIN, LABELS_VAL):
        d.mkdir(parents=True, exist_ok=True)

    prefix = _prefix_from_path(video_path)
    print(f"Video  : {video_path}")
    print(f"Model  : {model_path}")
    print(f"Conf   : >= {conf}  (only keep detections above this threshold)")
    print(f"Sample : {fps} fps  (take one frame every ~{1/fps:.2f}s)")
    print(f"Val    : {val_fraction:.0%} of saved frames go to val/")
    print(f"Prefix : {prefix}_")
    if dry_run:
        print("DRY RUN — no files will be written\n")
    else:
        print()

    # ------------------------------------------------------------------ #
    # 2. Load model
    # ------------------------------------------------------------------ #
    print("Loading model…")
    model = YOLO(str(model_path))

    # ------------------------------------------------------------------ #
    # 3. Open video and figure out the sampling step
    #    e.g. a 60fps video sampled at 3fps → keep every 20th frame
    # ------------------------------------------------------------------ #
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise SystemExit(f"Could not open video: {video_path}")

    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    step = max(1, int(round(src_fps / fps)))

    print(f"Video  : {total_frames} frames @ {src_fps:.1f} fps → "
          f"sampling every {step} frames (~{total_frames // step} candidates)\n")

    # ------------------------------------------------------------------ #
    # 4. Figure out what frame numbers already exist for this prefix so we
    #    don't overwrite them if we run the script twice on the same video.
    # ------------------------------------------------------------------ #
    existing = set()
    for d in (IMAGES_TRAIN, IMAGES_VAL):
        for f in d.glob(f"{prefix}_*.jpg"):
            # Extract the number part: "phaze_ii_00042.jpg" → 42
            m = re.search(r"_(\d+)\.jpg$", f.name)
            if m:
                existing.add(int(m.group(1)))

    next_idx = max(existing, default=-1) + 1

    # ------------------------------------------------------------------ #
    # 5. Main loop — read, sample, detect, save
    # ------------------------------------------------------------------ #
    saved_train = 0
    saved_val   = 0
    skipped     = 0   # frames where no confident detection found
    frame_n     = 0

    random.seed(42)   # reproducible val split

    while True:
        ok, frame = cap.read()
        if not ok:
            break

        # Only process every Nth frame
        if frame_n % step != 0:
            frame_n += 1
            continue

        img_h, img_w = frame.shape[:2]

        # ------------------------------------------------------------------ #
        # Run the detector on this frame.
        # We only look at class 0 (bowling_ball — our custom class).
        # verbose=False stops it from printing a line per frame.
        # ------------------------------------------------------------------ #
        results = model.predict(
            source=frame,
            conf=conf,
            classes=[BALL_CLASS],
            verbose=False,
        )

        boxes = results[0].boxes
        if boxes is None or len(boxes) == 0:
            # No confident detection — skip this frame
            skipped += 1
            frame_n += 1
            continue

        # If there are multiple detections, take the one with the highest confidence.
        # (Reflections or duplicate boxes occasionally appear; the most confident
        # one is almost always the real ball.)
        best_idx = int(boxes.conf.argmax())
        x1, y1, x2, y2 = boxes.xyxy[best_idx].cpu().numpy()
        label_line = _to_yolo_label(x1, y1, x2, y2, img_w, img_h)

        # Decide train vs val: roughly val_fraction of saved frames go to val
        go_val = random.random() < val_fraction
        img_dir = IMAGES_VAL   if go_val else IMAGES_TRAIN
        lbl_dir = LABELS_VAL   if go_val else LABELS_TRAIN

        fname = f"{prefix}_{next_idx:05d}"
        img_path = img_dir / f"{fname}.jpg"
        lbl_path = lbl_dir / f"{fname}.txt"

        if not dry_run:
            cv2.imwrite(str(img_path), frame)
            lbl_path.write_text(label_line + "\n")

        if go_val:
            saved_val += 1
        else:
            saved_train += 1

        next_idx += 1
        frame_n  += 1

    cap.release()

    # ------------------------------------------------------------------ #
    # 6. Summary
    # ------------------------------------------------------------------ #
    total_saved = saved_train + saved_val
    total_candidates = (total_frames // step)
    pct = 100 * total_saved / total_candidates if total_candidates else 0

    print(f"Done.")
    print(f"  Sampled  : {total_candidates} frames")
    print(f"  Saved    : {total_saved} ({pct:.0f}%)  →  {saved_train} train / {saved_val} val")
    print(f"  Skipped  : {skipped} (no detection above conf={conf})")

    if total_saved == 0:
        print("\nNothing was saved. Try lowering --conf (e.g. --conf 0.35).")
    elif not dry_run:
        print(f"\nNext: delete the label cache so YOLO picks up the new files:")
        print(f"  rm -f dataset/ball_yolo/labels/train.cache dataset/ball_yolo/labels/val.cache")
        print(f"Then retrain:")
        print(f"  python3 training/train_ball_detector.py \\")
        print(f"    --data dataset/ball_yolo/data.yaml \\")
        print(f"    --model models/ball.pt --epochs 80")


def main() -> None:
    p = argparse.ArgumentParser(
        description="Auto-label frames from a bowling video using ball.pt (pseudo-labeling)"
    )
    p.add_argument(
        "--video", "-v", type=Path, required=True,
        help="Path to the bowling video"
    )
    p.add_argument(
        "--model", "-m", type=Path, default=Path("models/ball.pt"),
        help="Trained YOLO weights to use (default: models/ball.pt)"
    )
    p.add_argument(
        "--conf", type=float, default=0.50,
        help="Min confidence to accept a detection as a label (default: 0.50)"
    )
    p.add_argument(
        "--fps", type=float, default=3.0,
        help="How many frames per second to sample from the video (default: 3)"
    )
    p.add_argument(
        "--val-split", type=float, default=0.15,
        help="Fraction of saved frames to put in val/ instead of train/ (default: 0.15)"
    )
    p.add_argument(
        "--dry-run", action="store_true",
        help="Print what would be saved without writing any files"
    )
    args = p.parse_args()

    if not (0.0 < args.conf < 1.0):
        raise SystemExit("--conf must be between 0 and 1")
    if not (0.0 <= args.val_split < 1.0):
        raise SystemExit("--val-split must be between 0 and 1")

    run(args.video, args.model, args.conf, args.fps, args.val_split, args.dry_run)


if __name__ == "__main__":
    main()
