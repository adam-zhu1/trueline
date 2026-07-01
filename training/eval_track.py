#!/usr/bin/env python3
"""
Run the full Trueline tracking pipeline headless and print its console output.

Used to compare shot metrics (speed / arrows / breakpoint / entry angle) and
TRUELINE_DEBUG_TRACK coasting behavior before vs after model or tracker changes,
without clicking through OpenCV windows.

How: stubs out cv2.imshow/waitKey before importing ball_tracking. track_ball's
main loop polls waitKey(1) (keep going -> -1) and its final "press Q" screen
polls waitKey(50) (quit -> 'q'), so the stub keys off the delay argument.

  TRUELINE_DEBUG_TRACK=1 python3 training/eval_track.py --video "data/....MP4"
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))


def _stub_gui():
    cv2.imshow = lambda *a, **k: None
    cv2.namedWindow = lambda *a, **k: None
    cv2.destroyAllWindows = lambda *a, **k: None
    cv2.waitKey = lambda delay=0: ord("q") if delay >= 50 else -1


def main() -> None:
    p = argparse.ArgumentParser(description="Headless tracking run")
    p.add_argument("--video", "-v", type=Path, required=True)
    p.add_argument("--calibration", type=Path, default=Path("data/calibration.json"))
    args = p.parse_args()

    calibration = json.loads(args.calibration.read_text())
    _stub_gui()
    from ball_tracking import track_ball

    track_ball(str(args.video), calibration)


if __name__ == "__main__":
    main()
