# TrueLine

An iOS app that turns a single iPhone into a bowling ball tracker: per-throw launch speed, board at the arrows, breakpoint, and entry angle. These metrics otherwise require a $10k+ in-lane installation. App Store launch in preparation.

Landing page: [adam-zhu1.github.io/trueline](https://adam-zhu1.github.io/trueline/)

---

## About

I bowled competitively in high school, and TrueLine comes from a problem I kept hitting: after a bad shot, it's genuinely hard to know whether to move or to fix the release. Foul-line board, breakpoint, and shot-to-shot speed blur in memory, so adjustments stay guesswork.

Enterprise lane systems cost $10k+ installed and need hardware on the lane. TrueLine's goal is the same class of metrics with no extra hardware, on every delivery, for league bowlers, school teams, and coaches who want objective feedback without enterprise pricing.

The technically interesting part is board-level accuracy from a side-mounted phone over a full lane: boards are about an inch wide across sixty feet, so pulling a reliable line and breakpoint out of casual video is a real CV/ML problem. That constraint drives the whole stack.

## How it works

- **Detection:** a fine-tuned YOLOv8 detector, bootstrapped from hand-labeled seed frames and grown with a model-assisted labeling loop, exported to Core ML. The full computer vision pipeline runs on-device with zero third-party dependencies.
- **Tracking:** constant-velocity Kalman filter with Savitzky-Golay smoothing of the tracked path.
- **Calibration:** a four-corner calibration homography maps any camera angle into real-world lane coordinates. A custom gutter-line detector proposes the corners and a magnifier-loupe drag UI refines them.
- **Verification:** a clip-by-clip parity harness (`experiments/shot_parity`) checks the Swift port against the Python/OpenCV prototype: board position agrees within 1 board and launch speed within 1-2%.

## What it measures

| Metric | How |
|--------|-----|
| **Speed (mph)** | Timing between foul-line and 6 ft dot-line crossings. |
| **Board at arrows** | Homography projects the ball's lane contact point onto the USBC arrow V (boards 5-35, 12-16 ft). Reported to 0.1 board. |
| **Breakpoint board** | Minimum homography board along the tracked path (trimmed to cut approach noise and pin-deck scatter). |
| **Entry angle (deg)** | Angle between the smoothed path and the boards over the final stretch before the pins, in real lane inches. |

All board/feet calculations use a perspective homography built from the four calibrated lane corners, with a parallax correction from ball center to lane contact point so metrics stay accurate from a low side angle. A 39-board model supports right- and left-handed bowlers.

## Repo layout

```
ios/Trueline/         SwiftUI app (Swift, Core ML, AVFoundation)
src/                  Python/OpenCV reference prototype
training/             YOLOv8 training scripts and docs
experiments/          Parity harness, lane auto-detection experiments
dataset/              YOLO dataset scaffolding (images/labels gitignored)
docs/                 Landing, support, and privacy pages (GitHub Pages)
```

## Python prototype

The `src/` prototype is the reference implementation the iOS app is verified against.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 src/main.py
```

- Enter the full path to the video file at the prompt.
- `R` reuses existing calibration; `C` recalibrates. `Q` quits.
- Optional YOLO detection: `pip install -r training/requirements-training.txt` and install a trained `models/ball.pt` (see `training/README.md`; weights are gitignored). `TRUELINE_BALL_MODEL=/path/to/other.pt` overrides the checkpoint.

## Tech stack

Swift, SwiftUI, Core ML, AVFoundation (app) · Python, PyTorch, OpenCV (prototype and training)

## Status

Working: speed, board at arrows, breakpoint, entry angle, on-device tracking, parity with the prototype. Next: App Store launch, session logging and consistency metrics, recommendations.

## License

MIT. See `LICENSE`.
