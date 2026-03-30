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

## Train

```bash
cd /path/to/pinpoint
source .venv/bin/activate
python training/train_ball_detector.py --data dataset/ball_yolo/data.yaml --epochs 80
```

Defaults use **YOLOv8n** (nano — fast, good baseline). Artifacts go under `runs/detect/`.

**Copy the best weights** into the repo so the app finds them:

```bash
mkdir -p models
cp runs/detect/train/weights/best.pt models/ball.pt
```

Run PinPoint as usual: if `models/ball.pt` exists, **`track_ball` uses YOLO** and skips MOG2. Override path:

```bash
export PINPOINT_BALL_MODEL=/path/to/custom.pt
```

---

## What the code does (inference)

1. `src/ball_detector.py` loads weights with Ultralytics `YOLO(path)`.
2. Each frame, `predict()` returns boxes; we **discard** boxes whose **center** is outside the **calibrated lane quadrilateral** (same foul/pin corners as the mask).
3. Boxes become `(cx, cy, r)` for the existing **Kalman** + `refine_ball_center` path in `detect_ball.py`.

So calibration still defines **where** the lane is; the network only answers **whether** a ball-like object is there.

---

## Troubleshooting

| Symptom | What to try |
|--------|-------------|
| No detections | Lower `conf` in `load_ball_detector()` or train longer; add harder negatives. |
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
