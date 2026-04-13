# PinPoint

Computer vision on phone video: ball speed, board at arrows, and breakpoint — from a single side-mounted camera, no extra hardware. Optional YOLO ball detection.

---

## About

I'm a first-year **Statistics & Machine Learning** student at **Carnegie Mellon University** and I bowled competitively in high school. I started PinPoint because of a problem I keep hitting: after a bad shot, it's genuinely hard to know whether to **move** or to **fix the release** — foul-line board, breakpoint, and shot-to-shot speed blur in memory, so adjustments stay guesswork.

Enterprise lane systems (e.g. **Specto**) cost on the order of **$15k** installed and need hardware on the lane. Apps like **LaneTrax** prove a phone can log a shot; what I want PinPoint to become is the same **no-extra-hardware** setup, with **solid metrics on every delivery** and, down the road, **recommendations** from that data — for league bowlers, high school and college teams, and coaches who want objective feedback without Specto-level pricing.

The piece of this that excites me technically is **board-level accuracy from a side-mounted phone** over a full lane: boards are on the order of an inch wide across sixty feet, so pulling reliable line and breakpoint out of casual video is a real **CV / ML** problem — and the reason the stack looks the way it does.

---

## What it measures

| Metric | How |
|--------|-----|
| **Speed (mph)** | Frame count between foul line and 6 ft dot line crossings × FPS. |
| **Board at arrows** | Homography projects the ball's lane contact point onto the USBC arrow V (board 5–35, 12–16 ft). Reported to 0.1 board. |
| **Breakpoint board** | Minimum homography board along the tracked path (trimmed to cut approach noise and pin-deck scatter). |

All board/feet calculations use a **perspective homography** (`image_to_lane`) built from four calibrated lane corners. A **parallax correction** offsets from the ball center to the lane contact point (bottom of the detected circle) so metrics are accurate from a low side angle.

---

## Approach

- **Detection:** MOG2 background subtraction + Hough circles + motion-blob fallback by default; optional **YOLOv8** if `models/ball.pt` exists.
- **Tracking:** Constant-velocity **Kalman filter** with nearest-candidate association; temporal EMA blend reduces jitter.
- **Calibration:** Six clicks on the first frame — foul line (right/left gutter), dot line at 6 ft (right/left), pin deck (right/left). Stored in `data/calibration.json`; reusable across videos from the same camera position.
- **39-board model:** Board 1 at the bowler's outside gutter, board 39 at the opposite side. Supports right- and left-handed bowlers.

---

## Output

Two OpenCV windows:

1. **PinPoint** — video with foul/dot/pin lines, ball trail (drawn at the lane contact point), breakpoint marker, and HUD (speed, arrow board).
2. **PinPoint — Lane View** — top-down schematic with smoothed ball path, arrow V, breakpoint dot, and metrics.

Terminal prints a shot summary after tracking finishes.

---

## Tech stack

Python 3.11+, OpenCV, NumPy; optional PyTorch + Ultralytics for YOLO (`training/`).

---

## Setup and run

```bash
cd /path/to/pinpoint
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**YOLO (optional):** `pip install -r training/requirements-training.txt`, then install a trained `models/ball.pt` (see `training/README.md`; weight files are gitignored).

```bash
python3 src/main.py
```

- Enter the **full path** to the video file at the prompt.
- **`R`** reuses existing calibration; **`C`** recalibrates.
- **`Q`** quits the preview or exits the final-frame hold.

**Custom weights:** `export PINPOINT_BALL_MODEL=/path/to/other.pt` to use a checkpoint other than `models/ball.pt`.

---

## Train or update the ball detector

See **`training/README.md`** for frame extraction, labeling, training, and installing `models/ball.pt`.

---

## Project layout

```
src/
  main.py             CLI entry point
  calibration.py      Six-click calibration, lane geometry constants
  ball_tracking.py    Detection, Kalman tracking, homography, metrics, overlays, lane view
  yolo_ball.py        Optional YOLO detector wrapper
training/             YOLO training scripts + docs
data/                 calibration.json (gitignored video/output files)
models/               ball.pt weights (gitignored)
```

---

## Status / roadmap

Working: speed, board at arrows, breakpoint, perspective lane view, parallax correction, right/left hand support.

Roadmap: session logging / consistency metrics, recommendations, mobile.

---

## Contact

Issues and PRs welcome.
