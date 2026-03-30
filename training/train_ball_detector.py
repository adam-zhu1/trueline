#!/usr/bin/env python3
"""
Fine-tune a YOLOv8 model on a single-class "bowling_ball" dataset.

How this fits the project
-------------------------
End users only calibrate and play video; this script is for training only. After
training, copy `best.pt` to `models/ball.pt`. The runtime (`src/yolo_ball.py`)
loads those weights and replaces the MOG2 + Hough candidate generator in `ball_tracking.py`.

What happens inside
-------------------
1. Ultralytics loads pretrained weights (default: yolov8n.pt — small and fast).
2. It reads `data.yaml` (paths to train/val images and class names).
3. It minimizes loss on the labeled boxes over many epochs (gradient descent
   on GPU/Metal/CPU).
4. Checkpoints: default `runs/detect/ball/weights/best.pt` (see `training/README.md`).

Usage:
  python3 training/train_ball_detector.py --data dataset/ball_yolo/data.yaml --model models/ball.pt --epochs 80
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
        type=str,
        default="",
        help="Subdirectory under runs/detect/ (default: empty → runs/detect/<name>/). "
        "Do not pass 'runs/detect' — Ultralytics already prefixes runs/detect/ and paths would double-nest.",
    )
    parser.add_argument(
        "--name",
        type=str,
        default="ball",
        help="Run name → runs/detect/<name>/weights/ when --project is omitted",
    )
    args = parser.parse_args()

    if not args.data.is_file():
        raise SystemExit(f"data.yaml not found: {args.data}")

    # Ultralytics builds save_dir as runs/detect/<project>/<name>. Passing project="runs/detect"
    # (or anything starting with runs/detect) double-nests folders — reject it.
    proj_raw = (args.project or "").strip().replace("\\", "/").strip("/")
    if proj_raw == "runs" or proj_raw.startswith("runs/detect"):
        raise SystemExit(
            "Invalid --project: Ultralytics already uses a `runs/detect/` root.\n"
            "  Omit --project (default) → weights in runs/detect/<name>/weights/best.pt\n"
            "  Or use a short subfolder only, e.g. --project exp_march → runs/detect/exp_march/ball/\n"
            "See training/README.md."
        )

    from ultralytics import YOLO

    device = _pick_device()
    print(f"Using device: {device}")
    sub = f"{proj_raw}/{args.name}" if proj_raw else args.name
    print(f"Training output (Ultralytics): runs/detect/{sub}/\n")

    model = YOLO(args.model)
    results = model.train(
        data=str(args.data.resolve()),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=device,
        project=args.project.strip() if args.project and args.project.strip() else None,
        name=args.name,
    )

    save_dir = getattr(results, "save_dir", None)
    if not save_dir:
        if proj_raw:
            save_dir = str(Path("runs") / "detect" / proj_raw / args.name)
        else:
            save_dir = str(Path("runs") / "detect" / args.name)
    weights_dir = Path(save_dir) / "weights"
    print("\nDone. Typical next step:")
    print(f"  mkdir -p models && cp {weights_dir}/best.pt models/ball.pt")
    print("Then run PinPoint — it will auto-load models/ball.pt if present.\n")


if __name__ == "__main__":
    main()
