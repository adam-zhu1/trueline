# PinPoint

Computer vision on phone video: ball speed, board line, breakpoint, rev rate (planned), with optional YOLO ball detection.

---

## About

PinPoint is a personal project by a first-year **Statistics & Machine Learning** student at **Carnegie Mellon University**, with a background in **competitive high school bowling**. The problem it targets is the one serious bowlers keep running into: after a bad shot, it is hard to tell whether to **move** or to **fix the release**—foul-line board, breakpoint, and shot-to-shot speed blur in memory, so changes stay guesswork.

Enterprise lane systems (e.g. **Specto**) cost on the order of **$15k** installed and require lane hardware. Apps such as **LaneTrax** show that a phone can log a shot; PinPoint is aimed at the same **no-extra-hardware** constraint while building toward **metrics on every delivery** and, eventually, **recommendations** from that data—for leagues, high school and college teams, and coaches who want objective feedback without Specto-level pricing.

The technical heart of the project is **board-level spatial accuracy from a side-mounted phone camera** over a full lane: boards are on the order of an inch wide across sixty feet, so extracting reliable line and breakpoint from casual video is a genuine CV / ML challenge.

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
