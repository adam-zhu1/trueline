# Training a bowling-ball detector (YOLO)

This guide is for **you** (the developer) — not for end users. Players only need to **calibrate** and run; they never see this folder. Your M4 Max is ideal for training with **Apple Metal (MPS)**.

---

## What problem this solves

The built-in tracker uses **motion** (background subtraction + circles). It confuses feet, shadows, and reflections with the ball. A **small neural network** learns to answer: “Does this patch look like a bowling ball?” That is **much** more stable across lighting and house conditions.

**Transfer learning**: We start from **YOLOv8n** weights pretrained on COCO (many object categories), then **fine-tune** on *only* your “bowling_ball” class. You are not training from scratch.

---

## Concepts (short)

| Term | Meaning |
|------|--------|
| **Bounding box** | Rectangle `(x1,y1,x2,y2)` around the ball in the image. |
| **YOLO** | “You Only Look Once” — one forward pass per image, outputs boxes + scores. |
| **Class** | Here we use **one** class: index `0` = `bowling_ball`. |
| **Label file** | For each image `foo.jpg`, a text file `foo.txt` with one line per box: `class cx cy w h` with **normalized** center and size in `[0,1]`. |
| **data.yaml** | Tells Ultralytics where train/val images and labels live, and class names. |
| **Fine-tune** | Adjust pretrained weights on your dataset; faster and needs less data than training from zero. |

---

## Dataset layout

The repo includes **`dataset/ball_yolo/`** with `images/train`, `images/val`, `labels/train`, `labels/val`, and **`data.yaml`** — use that, or copy the same layout elsewhere.

```
dataset/ball_yolo/
  data.yaml
  images/train/   # .jpg / .png
  images/val/
  labels/train/   # .txt per image, same base name
  labels/val/
```

**Val** should be **different videos** than train (generalization test), typically 15–20% of images.

**Empty labels**: If a frame has **no** ball (or you skip it), you can omit the image or use an **empty** `.txt` — YOLO uses those as hard negatives.

**How many images?** Rough guide: **100–300** labeled frames to see a clear improvement; **500+** for something solid. Diversity (centers, oil, day/night) beats sheer count from one session.

---

## Labeling tools

- **[CVAT](https://www.cvat.ai/)** — web UI, export “YOLO 1.1”.
- **[Label Studio](https://labelstud.io/)** — flexible; export and convert to YOLO format.
- **Roboflow** — hosted; can export YOLOv8.

Export **YOLO** format: one `.txt` per image, normalized `class cx cy w h`.

---

## `data.yaml`

Use **`dataset/ball_yolo/data.yaml`** in this repo (`path: .` is this folder). If Ultralytics complains, change `path` to the **absolute** path of `dataset/ball_yolo/`.

Alternatively copy `training/data.yaml.template` and set `path` yourself.

---

## Install training dependencies (once)

From the project root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -r training/requirements-training.txt
```

PyTorch on Mac with MPS is usually installed via `pip install torch` (see [pytorch.org](https://pytorch.org/) if you need a specific build). Ultralytics will use **MPS** automatically when `torch.backends.mps.is_available()` is true.

---

## Step-by-step: add more data and train the model

Use this for your **first** training run and anytime you want the detector to work better on **new** lanes, angles, or lighting. You keep **one** dataset folder and **one** `ball.pt`; you just **add** images/labels and **train again**.

### 1. Activate the project environment

From the **repo root** (`pinpoint/`):

```bash
cd /path/to/pinpoint
source .venv/bin/activate
```

Install deps once (see [Install training dependencies](#install-training-dependencies-once) above). Always run `pip` and `python` **after** `activate` so packages match the interpreter that runs PinPoint.

### 2. Get still frames from new videos

You need **images** on disk before labeling. Two options:

**A. Script in this repo** (OpenCV; good default):

```bash
python training/extract_frames.py \
  --input /path/to/video.mp4 \
  --output dataset/ball_yolo/images/train \
  --fps 3 \
  --prefix myhouse_night_
```

- **`--prefix`** — Use a **unique prefix per video or session** so new files do not overwrite old ones (`myhouse_night_00000.jpg`, …).
- **`--fps`** — Lower = fewer frames (less labeling); higher = more diversity.

**B. ffmpeg** (if you prefer the command line):

```bash
mkdir -p dataset/ball_yolo/images/train
ffmpeg -i /path/to/video.mp4 -vf fps=3 "dataset/ball_yolo/images/train/newclip_%05d.jpg"
```

Raw frames under `images/train/` are fine to accumulate over time; you do not need a separate folder per training run.

### 3. Label the ball

1. Open **[CVAT](https://www.cvat.ai/)** (or another tool listed in [Labeling tools](#labeling-tools)).
2. Create a project with **one class**, e.g. `bowling_ball` (YOLO class index **0**).
3. Upload the new images from `dataset/ball_yolo/images/train` (or a copy).
4. Draw a **tight box** around the ball on each frame where it is visible.
5. Export **YOLO 1.1** (or YOLO-compatible `.txt` labels: normalized `class cx cy w h`).

**Frames with no ball** (approach, pins only): either skip them or add the image with an **empty** `.txt` label file (same base name as the image). Those are **hard negatives** and help reduce false positives.

### 4. Put images and labels in the dataset folders

Layout (under `dataset/ball_yolo/`):

| You add | Where |
|--------|--------|
| Training images | `images/train/*.jpg` (or `.png`) |
| Training labels | `labels/train/*.txt` — **same basename** as the image (`foo.jpg` → `foo.txt`) |
| Validation images | `images/val/` |
| Validation labels | `labels/val/` — same pairing rule |

**Validation** should include frames from **different videos** than train when possible (about **15–20%** of your total), so metrics reflect generalization.

After copying exported files from CVAT, fix any path mismatch: every image in `images/train` should have a matching `labels/train` file (or deliberately omit rare negatives if your tool exported empty labels).

### 5. Train (or retrain)

From repo root, venv on:

```bash
python training/train_ball_detector.py --data dataset/ball_yolo/data.yaml --epochs 80
```

- Weights and logs go under **`runs/ball/`** (see `--project` / `--name` in `train_ball_detector.py`). The good checkpoint is usually:

  `runs/ball/weights/best.pt`

  If Ultralytics nests another `runs/detect` inside, check the printed **`save_dir`** at the end of training.

**Starting from your current app weights** (fine-tune instead of from `yolov8n.pt` only):

```bash
python training/train_ball_detector.py \
  --data dataset/ball_yolo/data.yaml \
  --model models/ball.pt \
  --epochs 80
```

Use this when you already have a decent `models/ball.pt` and only added **new** hard examples.

### 6. Use the new model in PinPoint

```bash
mkdir -p models
cp runs/ball/weights/best.pt models/ball.pt
```

Then run PinPoint from `src/` as usual; it auto-loads `models/ball.pt` if `torch` + `ultralytics` are installed. To point at another file temporarily:

```bash
export PINPOINT_BALL_MODEL=/path/to/custom.pt
```

### 7. Repeat later

When a **new** video misbehaves: extract frames → label → add to `images/train` (and refresh `val`) → train again → copy `best.pt` to `models/ball.pt`. One model file can serve **many** videos; you only retrain to cover **new** visual conditions.

---

## Quick reference (train and deploy)

```bash
cd /path/to/pinpoint
source .venv/bin/activate
python training/train_ball_detector.py --data dataset/ball_yolo/data.yaml --epochs 80
mkdir -p models && cp runs/ball/weights/best.pt models/ball.pt
```

Override weights path at runtime: `export PINPOINT_BALL_MODEL=/path/to/custom.pt`

---

## What the code does (inference)

1. `src/yolo_ball.py` loads weights with Ultralytics `YOLO(path)`.
2. Each frame, `predict()` returns boxes; we **discard** boxes whose **center** is outside the **calibrated lane quadrilateral** (same foul/pin corners as the mask).
3. Boxes become `(cx, cy, r)` for the existing **Kalman** + `refine_ball_center` path in `ball_tracking.py`.

So calibration still defines **where** the lane is; the network only answers **whether** a ball-like object is there.

---

## Troubleshooting

| Symptom | What to try |
|--------|-------------|
| No detections | Lower `conf` in `load_yolo_ball()` or train longer; add harder negatives. |
| False positives | Raise `conf`; add more negative frames; label reflections as background (no box). |
| Jitter | Usually association/Kalman — same as classical mode; detector gives better centers first. |
| Slow | Use `yolov8n.pt`; reduce `imgsz`; export ONNX later for a slimmer runtime. |

---

## Learning path (if you want depth)

1. Read Ultralytics **Train** docs: [docs.ultralytics.com/modes/train](https://docs.ultralytics.com/modes/train/).
2. Watch how **mAP** and **loss** change on **val** — overfitting shows val getting worse while train improves.
3. When comfortable, experiment with **augmentation** (Ultralytics YAML `augment` section) or a slightly larger model (`yolov8s.pt`).

---

## Privacy / ethics

Only train on footage you have rights to use. If you ever ship a public app, document that model weights are derived from user-consented data if applicable.
