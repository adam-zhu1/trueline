# PinPoint 🎳

A computer vision pipeline for extracting bowling performance metrics from phone video (ball speed, rev rate, board tracking, and breakpoint detection) with a planned ML recommendation layer.

---

## Overview

PinPoint processes raw phone camera footage of a bowling delivery and extracts structured performance data without any specialized hardware. The core challenge is accurate ball tracking across a 60-foot lane, board-level spatial resolution (boards are ~1 inch wide), and rev rate estimation from standard frame rates.

---

## Technical Approach

### Ball Detection & Tracking
- **Default:** OpenCV **MOG2** + Hough / blobs + Kalman (no ML install required).
- **Optional:** Fine-tuned **YOLO** weights at `models/ball.pt` — appearance-based detection, better across lighting; see **`training/README.md`** for dataset layout and training on Apple Silicon (MPS).
- Kalman filtering for smooth trajectory estimation and handling occlusion frames
- Lane geometry from calibration; detector boxes are filtered to the lane polygon

### Board Tracking
- Click-based lane geometry (foul line, 6 ft dot line, pin deck) defines the lane in the frame
- Board numbers use linear interpolation along each reference line: board 1 at the far edge, board 60 at the near edge
- Ball board is recorded when the smoothed track crosses the foul line and the dot line (full homography is still future work)

### Rev Rate Estimation
- Logo/marking detection on ball surface across frames
- Angular velocity calculation from rotation tracking
- Target accuracy: ±50 RPM at standard 240fps slow-motion capture

### Speed Calculation
- Time from foul line to the **6 ft dot line** (not the 15 ft arrow markers, which are not collinear)
- `speed_mph` from feet-per-second using the regulation 6 ft segment and video FPS

### Breakpoint Detection
- Lateral direction change on a smoothed x-trajectory, confirmed only after the new direction holds for several frames; detection starts after the ball reaches the dot line (reduces noise near the foul line)
- Down-lane distance is measured by projecting the ball onto the foul-mid → pin-mid axis and scaling with the calibrated foul-to-dot segment (not raw image `y`, which skews distance on a side view)

### Recommendation Engine *(planned)*
- Statistical model trained on shot outcome data (strike/spare/split) correlated with entry angle, board, and speed
- Given current lane conditions and recent shot history, output suggested adjustments (board, target, speed)

---

## Tech Stack

| Component | Tool |
|---|---|
| Language | Python 3.11 |
| CV Pipeline | OpenCV |
| Numerical | NumPy, SciPy |
| ML (optional ball detector) | Ultralytics YOLO + PyTorch *(see `training/`)* |
| Mobile | TBD |

---

## Status

🚧 Early stage — building and validating core CV pipeline.

Calibration JSON uses `dot_line_near` / `dot_line_far` and `dot_line_y` (6 ft dot row). Re-run calibration after any change to dot distance or lane clicks so `pixels_per_foot` matches; older `arrow_line_*` keys also require re-calibration.

---

## Roadmap

- [x] Ball detection and tracking from phone video *(MOG2 + Hough + Kalman; optional YOLO in `models/ball.pt`)*
- [ ] Perspective correction and lane homography
- [x] Board identification at foul line and dot line *(linear interpolation; pins/breakpoint board TBD)*
- [ ] Rev rate estimation via rotation tracking
- [x] Speed calculation *(foul to 6 ft dot line)*
- [x] Breakpoint detection *(with multi-frame confirmation; feet approximate)*
- [ ] Consistency metrics across multiple shots
- [ ] Recommendation engine (ML model)
- [ ] Mobile app interface

---

## Setup

### 1. Clone and enter the repo

Use whatever folder you keep projects in (examples: `~/Projects/pinpoint`, `~/Developer/pinpoint`).

```bash
cd /path/to/pinpoint
```

### 2. Virtual environment and dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**YOLO ball tracking** also needs PyTorch + Ultralytics (same venv):

```bash
pip install -r training/requirements-training.txt
```

Always **`source .venv/bin/activate`** before `pip` and `python3` so installs match the interpreter that runs the app.

### 3. Run PinPoint

From the **repo root** (where `src/` and `data/` live):

```bash
python3 src/main.py
```

Alternatively: `cd src && python3 main.py`.

1. Paste the **full path** to your video when prompted.
2. **Do not** wrap the path in single quotes (e.g. wrong: `'.../file.MP4'`). If the path has **spaces**, use **double quotes** in the shell or paste the path plain — the app strips a single pair of surrounding quotes if you paste them by mistake.
3. **Calibration:** Lane geometry is stored once in **`data/calibration.json`** (not per video). **`R`** reuses it if the camera view matches; **`C`** recalibrates from this clip’s first frame (new phone position, lane, or zoom).
4. During tracking, **`Q`** exits early; when the video ends, the last frame stays until **`Q`**.

**YOLO:** If `models/ball.pt` exists and `torch` + `ultralytics` import correctly, the app uses YOLO automatically; the video overlay shows **`YOLO: ball.pt`** in the corner. Otherwise it falls back to **MOG2 + Hough** and prints why. Override weights: `export PINPOINT_BALL_MODEL=/path/to/other.pt`.

**Playback speed** is not locked to real time — each frame is fully processed first, so preview can look slow on heavy clips or YOLO; that is expected.

### 4. Train or update the ball detector (optional)

Full workflow (extract frames → CVAT → dataset folders → train → copy weights) is in **`training/README.md`**. After each successful train, copy the printed **`best.pt`** path to:

```bash
mkdir -p models
cp <path-from-training-output>/best.pt models/ball.pt
```

Optional: back up the old weights first: `cp models/ball.pt models/ball.pt.backup`.

---

## About

Built by a first-year Stat/ML student at Carnegie Mellon University with a background in competitive bowling.

---

## Contact

Have feedback or want to collaborate? Open an issue or reach out directly.
