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
- Homographic transformation to map pixel coordinates to real-world lane coordinates
- Lane line detection to establish board grid (60 boards, each ~1 inch wide)
- Ball position mapped to board number at key moments: foul line, breakpoint, and entry angle at pins

### Rev Rate Estimation
- Logo/marking detection on ball surface across frames
- Angular velocity calculation from rotation tracking
- Target accuracy: ±50 RPM at standard 240fps slow-motion capture

### Speed Calculation
- Time-of-flight estimation using known lane length (60 feet)
- Cross-validated against frame-by-frame displacement in corrected coordinates

### Breakpoint Detection
- Trajectory analysis to identify inflection point where lateral ball motion changes direction
- Board number and distance from foul line recorded as output

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

---

## Roadmap

- [ ] Ball detection and tracking from phone video
- [ ] Perspective correction and lane homography
- [ ] Board identification at foul line and breakpoint
- [ ] Rev rate estimation via rotation tracking
- [ ] Speed calculation
- [ ] Breakpoint detection
- [ ] Consistency metrics across multiple shots
- [ ] Recommendation engine (ML model)
- [ ] Mobile app interface

---

## About

Built by a first-year Stat/ML student at Carnegie Mellon University with a background in competitive bowling.

---

## Contact

Have feedback or want to collaborate? Open an issue or reach out directly.
