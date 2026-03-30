# Ball dataset (YOLO) — step by step

This folder is your **workspace** for training. Nothing here is required until you add images and labels.

## Layout

```
ball_yolo/
  data.yaml          ← already set up (one class: bowling_ball)
  images/
    train/           ← put most of your .jpg / .png frames here
    val/             ← put ~15–20% of frames from *other* videos here
  labels/
    train/           ← one .txt per image (YOLO format), same file name
    val/
```

## Steps (we’ll do these together)

| Step | What you do |
|------|----------------|
| **1** | Drop or extract **images** into `images/train/` (and later `images/val/`). |
| **2** | Label boxes in CVAT (or similar), **export YOLO**, copy `.txt` files into `labels/train/` and `labels/val/` matching each image name. |
| **3** | From the PinPoint repo, with venv on: `pip install -r training/requirements-training.txt` |
| **4** | Train: `python3 training/train_ball_detector.py --data dataset/ball_yolo/data.yaml --epochs 80` |
| **5** | `mkdir -p models && cp runs/detect/train/weights/best.pt models/ball.pt` |

## Rules

- For `frame_001.jpg` you need `frame_001.txt` in the matching **labels/** split (train vs val).
- Class id is always **0** (`bowling_ball`).
- Empty `.txt` = image has no ball (optional hard negatives).

When step 1 is done (you have some images in `train`), say so and we’ll do labeling exports next.
