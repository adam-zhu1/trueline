# Training the ball detector (YOLO)

Fine-tune YOLOv8 on labeled frames; PinPoint loads **`models/ball.pt`** at runtime (`src/yolo_ball.py`). Class **0** = `bowling_ball`. Labels: YOLO `cx cy w h` normalized; empty `.txt` = no ball.

---

## Paths (repo root)

| Location | Purpose |
|----------|---------|
| `dataset/ball_yolo/` | `data.yaml`, `images/{train,val}/`, `labels/{train,val}/` |
| `runs/detect/ball/weights/best.pt` | Default training output (gitignored) |
| `models/ball.pt` | Trained weights for the app; install by copying `best.pt` (gitignored) |

---

## One-time setup

```bash
cd /path/to/pinpoint
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
