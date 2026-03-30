# PinPoint 🎳

A computer vision pipeline for extracting bowling performance metrics from phone video (ball speed, rev rate, board tracking, and breakpoint detection) with a planned ML recommendation layer.

---

## Overview

PinPoint processes raw phone camera footage of a bowling delivery and extracts structured performance data without any specialized hardware. The core challenge is accurate ball tracking across a 60-foot lane, board-level spatial resolution (boards are ~1 inch wide), and rev rate estimation from standard frame rates.

---

## Technical Approach

### Ball Detection & Tracking
- Frame-by-frame ball localization using **OpenCV** (Hough Circle Transform + contour detection)
- Kalman filtering for smooth trajectory estimation and handling occlusion frames
- Perspective correction to account for camera angle and position variance

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
| ML Layer | PyTorch *(planned)* |
| Mobile | TBD |

---

## Status

🚧 Early stage — building and validating core CV pipeline.

Calibration JSON uses `dot_line_near` / `dot_line_far` and `dot_line_y` (6 ft dot row). Re-run calibration after any change to dot distance or lane clicks so `pixels_per_foot` matches; older `arrow_line_*` keys also require re-calibration.

---

## Roadmap

- [x] Ball detection and tracking from phone video *(MOG2 + Hough + Kalman; ongoing tuning)*
- [ ] Perspective correction and lane homography
- [x] Board identification at foul line and dot line *(linear interpolation; pins/breakpoint board TBD)*
- [ ] Rev rate estimation via rotation tracking
- [x] Speed calculation *(foul to 6 ft dot line)*
- [x] Breakpoint detection *(with multi-frame confirmation; feet approximate)*
- [ ] Consistency metrics across multiple shots
- [ ] Recommendation engine (ML model)
- [ ] Mobile app interface

---

## About

Built by a first-year Stat/ML student at Carnegie Mellon University with a background in competitive bowling.

---

## Contact

Have feedback or want to collaborate? Open an issue or reach out directly.
