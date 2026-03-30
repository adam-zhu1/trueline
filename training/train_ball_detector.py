#!/usr/bin/env python3
"""
Fine-tune a YOLOv8 model on a single-class "bowling_ball" dataset.

How this fits the project
-------------------------
End users only calibrate and play video; they do not run this script. After
training, you copy `best.pt` to `models/ball.pt`. The runtime (`ball_detector.py`)
loads those weights and replaces the MOG2 + Hough candidate generator.

What happens inside
-------------------
1. Ultralytics loads pretrained weights (default: yolov8n.pt — small and fast).
2. It reads your `data.yaml` (paths to train/val images and class names).
3. It minimizes a loss on your bounding boxes over many epochs (gradient descent
   on GPU/Metal/CPU).
4. Checkpoints land under `runs/detect/`; `best.pt` is the best validation score.

Usage (from repo root, venv activated):
  python training/train_ball_detector.py --data /path/to/data.yaml --epochs 80
"""

from __future__ import annotations

import argparse
from pathlib import Path


def _pick_device() -> str:
    """Prefer CUDA, then Apple MPS, then CPU."""
    import torch

    if torch.cuda.is_available():
        return "0"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def main() -> None:
    parser = argparse.ArgumentParser(description="Train PinPoint bowling-ball YOLO")
    parser.add_argument(
        "--data",
        type=Path,
        required=True,
        help="Path to data.yaml (see training/data.yaml.template)",
    )
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--imgsz", type=int, default=640, help="Square resize for training")
    parser.add_argument(
        "--model",
        type=str,
        default="yolov8n.pt",
        help="Ultralytics pretrained starting point (yolov8n.pt is fast)",
    )
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument(
        "--project",
        type=Path,
        default=Path("runs"),
        help="Ultralytics project dir (avoid runs/detect — YOLO may nest another runs/detect inside)",
    )
    parser.add_argument(
        "--name",
        type=str,
        default="ball",
        help="Run name (weights in project/name/weights/)",
    )
    args = parser.parse_args()

    if not args.data.is_file():
        raise SystemExit(f"data.yaml not found: {args.data}")

    from ultralytics import YOLO

    device = _pick_device()
    print(f"Using device: {device}")

    model = YOLO(args.model)
    results = model.train(
        data=str(args.data.resolve()),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=device,
        project=str(args.project),
        name=args.name,
    )

    save_dir = getattr(results, "save_dir", None) or str(args.project / args.name)
    weights_dir = Path(save_dir) / "weights"
    print("\nDone. Typical next step:")
    print(f"  mkdir -p models && cp {weights_dir}/best.pt models/ball.pt")
    print("Then run PinPoint — it will auto-load models/ball.pt if present.\n")


if __name__ == "__main__":
    main()
