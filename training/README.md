# Training the ball detector (YOLO)

Fine-tune YOLOv8 on labeled frames; Trueline loads **`models/ball.pt`** at runtime (`src/yolo_ball.py`). Class **0** = `bowling_ball`. Labels: YOLO `cx cy w h` normalized; empty `.txt` = no ball.

---

## Paths (repo root)

| Location | Purpose |
|----------|---------|
| `dataset/ball_yolo/` | `data.yaml`, `images/{train,val}/`, `labels/{train,val}/` |
| `runs/detect/ball/weights/best.pt` | Default training output (gitignored) |
| `models/ball.pt` | Trained weights for the app; install by copying `best.pt` (gitignored) |

---

## Videos: train vs. test (keep them separate)

`data/` is gitignored, but keep two folders so footage never leaks across the
train/test boundary:

| Folder | Purpose |
|--------|---------|
| `data/train_videos/` | Videos used to build the dataset (auto-label / far-lane harvest run on these). |
| `data/test_videos/`  | **Held-out** clips for evaluation only — never labeled or trained on. |

Measure model quality on `data/test_videos/` (see `eval_far_lane.py` /
`eval_track.py` below). The moment you harvest frames from a clip it stops being
a valid test — record a fresh clip if you want to fold an old test video into
training. Far-lane harvesting also needs a calibration matching that video's
camera angle; auto-labeling does not.

---

## One-time setup

```bash
cd /path/to/trueline
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -r training/requirements-training.txt
```

---

## Normal workflow: auto-label → retrain

This is the main way to grow the dataset without manual labeling.
Run from the repository root with the virtual environment activated.

### 1. Auto-label a new video

```bash
python3 training/auto_label.py --video data/phaze-ii.mov
```

The script samples frames at 3 fps, runs `models/ball.pt` on each one, and saves
frames where the model is confident (≥ 0.50 by default) as new image + label pairs.
About 15% go to `val/` automatically; the rest go to `train/`.

Run it on every video you have:

```bash
python3 training/auto_label.py --video data/darren-tang-equinoxsolid.mov
python3 training/auto_label.py --video data/phaze-ii.mov
python3 training/auto_label.py --video data/the-hype.mov
python3 training/auto_label.py --video "data/ScreenRecording_03-30-2026 15-05-02_1.MP4"
```

Use `--dry-run` first to preview how many frames would be saved without writing anything:

```bash
python3 training/auto_label.py --video data/phaze-ii.mov --dry-run
```

### 2. Delete stale caches

```bash
rm -f dataset/ball_yolo/labels/train.cache dataset/ball_yolo/labels/val.cache
```

Ultralytics caches label files for speed. Deleting the cache forces it to re-scan
and pick up the new frames you just added.

### 3. Retrain

**Fine-tuning** from the current `models/ball.pt`:

```bash
python3 training/train_ball_detector.py \
  --data dataset/ball_yolo/data.yaml \
  --model models/ball.pt \
  --epochs 80
```

**Initial training** (no `models/ball.pt` yet): omit `--model` (starts from `yolov8n.pt`).

### 4. Install the new weights

```bash
cp runs/detect/ball/weights/best.pt models/ball.pt
```

If Ultralytics numbered the run differently (e.g. `ball2`), the training script
prints the exact path at the end.

### 5. Repeat

Run `auto_label.py` again on the same or new videos — the improved model will now
confidently detect more frames, generating even more training data.

---

## Far-lane workflow: harvest → retrain → measure

`auto_label.py` only keeps frames the model is already confident about, so the
hard cases (small/blurry ball past ~45 ft, among the pins) never enter the
dataset. `harvest_far_lane.py` fixes that with trajectory-gated pseudo-labeling:
confident detections anchor the shot, the expected position is predicted in lane
coordinates between/beyond anchors, and low-confidence detections within a tight
gate of the prediction are saved as labels. It also walks backward toward the
release (motion blur) and saves hard negatives (pin deck, machine motion) with
empty label files. **Calibration must match the video** — same camera setup as
`data/calibration.json`.

```bash
python3 training/harvest_far_lane.py --video data/my-shot.MP4 --dry-run   # preview
python3 training/harvest_far_lane.py --video data/my-shot.MP4
```

Then delete the caches and retrain as above. Saved frames are named by source
frame number, so re-running on the same video never duplicates data.

Measure far-lane detection recall before/after retraining (no ground truth
needed — a reference trajectory is fitted from confident mid-lane detections):

```bash
python3 training/eval_far_lane.py --video data/my-shot.MP4 --model runs/detect/ball/weights/best.pt
```

Run the full tracking pipeline headless (metrics + `TRUELINE_DEBUG_TRACK`
coasting report, no GUI interaction needed):

```bash
TRUELINE_DEBUG_TRACK=1 python3 training/eval_track.py --video data/my-shot.MP4
```

---

## Core ML export (iOS)

The iOS app bundles the detector as **`ios/Trueline/Trueline/ML/ball.mlpackage`**
(committed; Xcode compiles it into the app). Regenerate after retraining:

```bash
python3 - <<'PY'
from ultralytics import YOLO
YOLO("models/ball.pt").export(format="coreml", nms=True, half=True, imgsz=640)
PY
cp -R models/ball.mlpackage ios/Trueline/Trueline/ML/
```

`nms=True` bakes non-max suppression into the model so Vision's
`VNCoreMLRequest` returns ready-to-use `VNRecognizedObjectObservation` boxes.

### Baseline metrics (ball.pt of 2026-06-16, recorded 2026-07-01)

| Model | mAP50 | mAP50-95 | P | R |
|-------|-------|----------|---|---|
| ball.pt (PyTorch) | 0.985 | 0.881 | 0.976 | 0.998 |
| ball.mlpackage (fp16 + NMS) | 0.964 | 0.848 | 0.976 | 0.976 |

Far-lane recall on the held-out test clip (`eval_far_lane.py`, conf≥0.35):
100% in every bin from 10–60 ft; 87% at 0–10 ft (release motion blur).
The iOS pipeline (task #7 parity) should reproduce the mlpackage numbers.

---

## `data.yaml`

The dataset descriptor is **`dataset/ball_yolo/data.yaml`**. If Ultralytics fails to
resolve paths, set `path:` in that file to the **absolute** path of `dataset/ball_yolo/`.

---

## Troubleshooting

| Issue | Try |
|-------|-----|
| YOLO not used at runtime | `models/ball.pt` must exist; same venv needs `training/requirements-training.txt` installed. |
| `auto_label.py` saves 0 frames | Lower `--conf`, e.g. `--conf 0.35` |
| Bad val metrics after retraining | Val folder needs real ball boxes, not only empty labels. |
| Stale split after adding data | Delete `labels/train.cache` and `labels/val.cache`, then retrain. |
| Few / noisy detections at runtime | More training data; or tune `conf` in `load_yolo_ball()` in `src/yolo_ball.py`. |
