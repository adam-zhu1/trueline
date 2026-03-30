# PinPoint 🎳

Computer vision on phone video: ball speed, board line, breakpoint, rev rate (planned), with optional YOLO ball detection.

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

**YOLO:** `pip install -r training/requirements-training.txt`, then add `models/ball.pt` (train locally; weights are gitignored).

```bash
python3 src/main.py
```

- Paste the **full video path** when prompted. Paths with spaces: use **double quotes** in the shell.
- **`data/calibration.json`** is shared across videos; **`R`** reuse, **`C`** recalibrate.
- **`Q`** quits preview / ends hold on last frame.

**Weights:** `export PINPOINT_BALL_MODEL=/path/to/other.pt` to override `models/ball.pt`.

---

## Train or update the ball detector

Exact copy-paste flow: **`training/README.md`** (extract → label → train → `cp best.pt` → run).

---

## Status / roadmap

Early stage. Calibration must match current lane UI (`dot_line_*` in JSON). Roadmap items: homography, rev rate, consistency metrics, recommendations, mobile.

---

## Contact

Issues and PRs welcome.
