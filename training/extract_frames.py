#!/usr/bin/env python3
"""Extract frames from a video into a folder (uses OpenCV — no ffmpeg required)."""

import argparse
from pathlib import Path

import cv2


def main() -> None:
    p = argparse.ArgumentParser(description="Extract frames from video")
    p.add_argument("--input", "-i", type=Path, required=True, help="Video file path")
    p.add_argument(
        "--output",
        "-o",
        type=Path,
        required=True,
        help="Output directory for frame_00001.jpg ...",
    )
    p.add_argument(
        "--fps",
        type=float,
        default=3.0,
        help="Target frames per second to save (default: 3)",
    )
    p.add_argument("--prefix", type=str, default="frame", help="Filename prefix")
    args = p.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(args.input))
    if not cap.isOpened():
        raise SystemExit(f"Could not open video: {args.input}")

    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    if src_fps <= 0:
        src_fps = 30.0
    # Save every Nth frame to approximate --fps output
    step = max(1, int(round(src_fps / args.fps)))

    n = 0
    saved = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if n % step == 0:
            out = args.output / f"{args.prefix}_{saved:05d}.jpg"
            cv2.imwrite(str(out), frame)
            saved += 1
        n += 1
    cap.release()
    print(f"Wrote {saved} frames to {args.output}")


if __name__ == "__main__":
    main()
