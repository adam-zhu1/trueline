# Training the ball detector (YOLO)

Fine-tune YOLOv8 on labeled frames; PinPoint loads **`models/ball.pt`** at runtime (`src/yolo_ball.py`). Class **0** = `bowling_ball`. Labels: YOLO `cx cy w h` normalized; empty `.txt` = no ball.

---

## Paths (repo root)

| Location | Purpose |
|----------|---------|
| `dataset/ball_yolo/` | `data.yaml`, `images/{train,val}/`, `labels/{train,val}/` |
| `runs/detect/ball/weights/best.pt` | Default training output (gitignored) |
| `models/ball.pt` | Trained weights for the app; install by copying `best.pt` from the run directory (gitignored) |

If `runs/detect/ball` already exists, Ultralytics may write **`ball2`**, **`ball3`**, … instead — use the `save_dir` path printed at the end of training.

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

## Training workflow (repeat for each new batch of data)

From the repository root with the virtual environment activated (`source .venv/bin/activate`).

### 1. Frames

```bash
python3 training/extract_frames.py \
  --input "/path/to/video.mp4" \
  --output dataset/ball_yolo/images/train \
  --fps 3 \
  --prefix unique_prefix_
```

A **distinct `--prefix` per source video** avoids filename collisions in `images/train/`.

### 2. Label

[CVAT](https://www.cvat.ai/) or any YOLO-capable exporter: single class, tight boxes on the ball. After export, each image sits under `images/train/` or `images/val/` with a matching **`basename.txt`** in the corresponding `labels/` folder.

- **~15–20%** of image+label **pairs** should live under `images/val/` + `labels/val/` (ideally from different source videos than train).
- The validation split needs **some** non-empty labels (ball boxes), not only empty negatives.

### 3. Refresh caches (after moving files or changing labels)

```bash
rm -f dataset/ball_yolo/labels/train.cache dataset/ball_yolo/labels/val.cache
```

### 4. Train

**Fine-tuning** (existing `models/ball.pt`):

```bash
python3 training/train_ball_detector.py \
  --data dataset/ball_yolo/data.yaml \
  --model models/ball.pt \
  --epochs 80
```

**Initial training** (no `models/ball.pt` yet): omit `--model` (starts from `yolov8n.pt`).

```bash
python3 training/train_ball_detector.py \
  --data dataset/ball_yolo/data.yaml \
  --epochs 80
```

`--project runs/detect` is invalid (the training script rejects it). Default run directory is **`runs/detect/ball/`**.

### 5. Install weights

The training log ends with **`Done. Typical next step:`** and an exact `cp` path. A typical layout:

```bash
mkdir -p models
cp runs/detect/ball/weights/best.pt models/ball.pt
```

Optional: back up the previous checkpoint first, e.g. `cp models/ball.pt models/ball.pt.backup`.

### 6. Run

```bash
python3 src/main.py
```

Alternate weights path: `export PINPOINT_BALL_MODEL=/path/to/file.pt`

---

## Optional: ffmpeg instead of `extract_frames.py`

```bash
mkdir -p dataset/ball_yolo/images/train
ffmpeg -i /path/to/video.mp4 -vf fps=3 "dataset/ball_yolo/images/train/clip_%05d.jpg"
```

---

## `data.yaml`

The dataset descriptor is **`dataset/ball_yolo/data.yaml`**. If Ultralytics fails to resolve paths, set `path:` in that file to the **absolute** path of `dataset/ball_yolo/`.

---

## Troubleshooting

| Issue | Try |
|-------|-----|
| YOLO not used | `models/ball.pt` present; same venv has `training/requirements-training.txt` installed. |
| Bad val metrics | Val includes real ball boxes, not only empty `.txt`. |
| Stale split | Delete `labels/train.cache` and `labels/val.cache`, train again. |
| Few / noisy detections | More data; tune `conf` in `load_yolo_ball()` in code. |

Ultralytics train docs: [docs.ultralytics.com/modes/train](https://docs.ultralytics.com/modes/train/).
