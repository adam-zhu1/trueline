# Ball dataset (YOLO format)

Directory layout for Ultralytics training. Populate `images/` and `labels/` before running `training/train_ball_detector.py`.

## Layout

```
dataset/ball_yolo/
  data.yaml          # Class list (e.g. bowling_ball); path relative to this folder
  images/
    train/           # Training frames (.jpg, .png, …)
    val/             # Validation frames (~15–20% of total; use frames from other videos when possible)
  labels/
    train/           # One .txt per image, same basename as the image (YOLO: class cx cy w h, normalized)
    val/
```

## Workflow

| Step | Action |
|------|--------|
| 1 | Place frames in `images/train/` (and `images/val/` after splitting). |
| 2 | Label in a tool such as [CVAT](https://www.cvat.ai/), export YOLO, place `.txt` files in `labels/train/` and `labels/val/` with matching image basenames. |
| 3 | Install training dependencies from the repo root: `pip install -r training/requirements-training.txt` (after activating the project virtual environment). |
| 4 | Train from the repo root: `python3 training/train_ball_detector.py --data dataset/ball_yolo/data.yaml --epochs 80` (add `--model models/ball.pt` when fine-tuning). |
| 5 | Copy the checkpoint Ultralytics reports (typically `runs/detect/ball/weights/best.pt`) to `models/ball.pt`. |

End-to-end instructions (frame extraction, cache cleanup, run commands): **`training/README.md`**.

## Conventions

- Each `image.jpg` has a matching `image.txt` in the same split (`train` or `val`).
- Class index is **0** (`bowling_ball`).
- An empty `.txt` marks a frame with no ball (optional hard negatives).
