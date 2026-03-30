# Training the ball detector (YOLO)

Fine-tune YOLOv8 on your frames; PinPoint loads **`models/ball.pt`** at runtime (`src/yolo_ball.py`). Class **0** = `bowling_ball`. Labels: YOLO `cx cy w h` normalized; empty `.txt` = no ball.

---

## Paths (repo root)

| Location | Purpose |
|----------|---------|
| `dataset/ball_yolo/` | `data.yaml`, `images/{train,val}/`, `labels/{train,val}/` |
| `runs/detect/ball/weights/best.pt` | Default training output (gitignored) |
| `models/ball.pt` | Copy `best.pt` here for the app (gitignored) |

If `runs/detect/ball` already exists, Ultralytics may use **`ball2`**, **`ball3`**, … — copy from the path printed when training finishes.

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

## Every time: add data → train → deploy

Always **`cd`** to repo root and **`source .venv/bin/activate`** first.

### 1. Frames

```bash
python3 training/extract_frames.py \
  --input "/path/to/video.mp4" \
  --output dataset/ball_yolo/images/train \
  --fps 3 \
  --prefix unique_prefix_
```

Use a **new `--prefix` per video** so files do not collide.

### 2. Label

Use [CVAT](https://www.cvat.ai/) (or any tool that exports YOLO). One class, tight boxes on the ball. Export YOLO; put each image and its matching **`basename.txt`** in `labels/train/` or `labels/val/`.

- Move **~15–20%** of image+label **pairs** to `images/val/` + `labels/val/` (prefer frames from other videos).
- Val must include **some** non-empty labels (ball boxes), not only empty negatives.

### 3. Refresh caches (after moving files or changing labels)

```bash
rm -f dataset/ball_yolo/labels/train.cache dataset/ball_yolo/labels/val.cache
```

### 4. Train

**You already have `models/ball.pt`:**

```bash
python3 training/train_ball_detector.py \
  --data dataset/ball_yolo/data.yaml \
  --model models/ball.pt \
  --epochs 80
```

**First train (no weights yet):** omit `--model` (starts from `yolov8n.pt`).

```bash
python3 training/train_ball_detector.py \
  --data dataset/ball_yolo/data.yaml \
  --epochs 80
```

Do **not** pass `--project runs/detect` (the script blocks it). Default run directory is **`runs/detect/ball/`**.

### 5. Install weights

Use the path in the **`Done. Typical next step:`** line. Often:

```bash
mkdir -p models
cp runs/detect/ball/weights/best.pt models/ball.pt
```

Optional backup: `cp models/ball.pt models/ball.pt.backup`

### 6. Run

```bash
python3 src/main.py
```

Override weights: `export PINPOINT_BALL_MODEL=/path/to/file.pt`

---

## Optional: ffmpeg instead of `extract_frames.py`

```bash
mkdir -p dataset/ball_yolo/images/train
ffmpeg -i /path/to/video.mp4 -vf fps=3 "dataset/ball_yolo/images/train/clip_%05d.jpg"
```

---

## `data.yaml`

Use **`dataset/ball_yolo/data.yaml`**. If Ultralytics errors on paths, set `path:` to the **absolute** path of `dataset/ball_yolo/`.

---

## Troubleshooting

| Issue | Try |
|-------|-----|
| YOLO not used | `models/ball.pt` present; same venv has `training/requirements-training.txt` installed. |
| Bad val metrics | Val includes real ball boxes, not only empty `.txt`. |
| Stale split | Delete `labels/train.cache` and `labels/val.cache`, train again. |
| Few / noisy detections | More data; tune `conf` in `load_yolo_ball()` in code. |

Ultralytics train docs: [docs.ultralytics.com/modes/train](https://docs.ultralytics.com/modes/train/).
