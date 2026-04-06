# PinPoint

Computer vision on phone video: ball speed, board line, breakpoint, rev rate (planned), with YOLO ball detection.

---

## About

I’m a first-year **Statistics & Machine Learning** student at **Carnegie Mellon University** and I bowled competitively in high school. I started PinPoint because of a problem I keep hitting: after a bad shot, it’s genuinely hard to know whether to **move** or to **fix the release**—foul-line board, breakpoint, and shot-to-shot speed blur in memory, so adjustments stay guesswork.

Enterprise lane systems (e.g. **Specto**) cost on the order of **$15k** installed and need hardware on the lane. Apps like **LaneTrax** prove a phone can log a shot; what I want PinPoint to become is the same **no-extra-hardware** setup, with **solid metrics on every delivery** and, down the road, **recommendations** from that data—for league bowlers, high school and college teams, and coaches who want objective feedback without Specto-level pricing.

The piece of this that excites me technically is **board-level accuracy from a side-mounted phone** over a full lane: boards are on the order of an inch wide across sixty feet, so pulling reliable line and breakpoint out of casual video is a real **CV / ML** problem—and the reason the stack looks the way it does.

---

## Approach (short)

- **Tracking:** MOG2 + Hough + Kalman by default; optional **YOLO** if `models/ball.pt` exists.
- **Lane:** Click calibration → foul line, 6 ft dot line, pin deck; boards interpolated (far = 1, near = 60).
- **Speed:** Foul line → 6 ft dot segment + FPS.
- **Breakpoint:** Lateral change after the dot line, multi-frame confirmation.

Details: `src/` and comments in `ball_tracking.py`.

---

## Tech stack

Python 3.11+, OpenCV, NumPy/SciPy; optional PyTorch + Ultralytics (`training/`).

---

## Setup and run

```bash
cd /path/to/pinpoint
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**YOLO:** `pip install -r training/requirements-training.txt`, then install a trained `models/ball.pt` (see `training/README.md`; weight files are gitignored).

```bash
python3 src/main.py
```

- At the prompt, enter the **full path** to the video file. Paths with spaces require **double quotes** in the shell.
- **`data/calibration.json`** is shared across videos; **`R`** reuse, **`C`** recalibrate.
- **`Q`** quits preview / ends hold on last frame.

**Weights:** `export PINPOINT_BALL_MODEL=/path/to/other.pt` selects a checkpoint other than `models/ball.pt`.

---

## Train or update the ball detector

Procedure: **`training/README.md`** (frame extraction, labeling, training, installing `models/ball.pt`, running the app).

---

## Status / roadmap

Early stage. Calibration must match current lane UI (`dot_line_*` in JSON). Roadmap items: homography, rev rate, consistency metrics, recommendations, mobile.

---

## Contact

Issues and PRs welcome.
