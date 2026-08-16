# Import robustness sweep — Aug 15, 2026

Six fresh imported test clips (two houses, three camera positions, dark and
swirl balls, all righty) run through the exact app analysis sources on macOS
via experiments/shot_parity, hand-placed corners, DEBUG diagnostics on.

## Detection / tracking (the model half)

| Clip | House | Raw boxes | Gate rejects | Track depth | 40ft+ conf | Speed | Entry° |
|------|-------|-----------|--------------|-------------|-----------|-------|--------|
| c1 | A (bright) | 134/203 frames | 0 | 58.9 ft | 0.84 | 16.0 | 5.7 |
| c2 | B (dim)    | 129/220 | 0 | 59.8 ft | 0.82 | 15.3 | 5.8 |
| c3 | B, high cam | 127/204 | 0 | 59.3 ft | 0.81 | 13.0 | 0.7 |
| c4 | A | 135/184 | 0 | 59.2 ft | 0.84 | 15.2 | 4.1 |
| c5 | A | 128/233 | 0 | 59.1 ft | 0.86 | 16.1 | 5.3 |
| c6 | B, high cam | 127/158 | 0 | 59.0 ft | 0.83 | 13.1 | 0.3 |

- 6/6 clips: full-lane tracks to ~59 ft, zero rejections at any gate,
  confidence 0.81–0.93 throughout. The June (~34 ft) and July (~20 ft)
  regression clips' depth limits were CLIP-specific (compression, ball/lane
  contrast), not a systemic ceiling. No new dataset blind spot surfaced —
  though no lane-colored ball appears in this set either; the gold-ball gap
  stands until retraining.
- No bad failures: nothing hung, nothing produced a confident garbage path.
  c2's far-left boards match the clip (a genuinely missed shot); c3/c6's low
  speed and flat entry correlate with the out-of-spec camera position
  (mounted on the ball return) plus the shakiest hand calibration — metrics
  degrade there, detection does not.
- Runtime ~1.3 s per 4–6 s clip on the M4 Max at -O.

## Lane auto-detect (the calibration half)

Same six first-frames through experiments/lane_autodetect_swift: 0/6 usable.
Five proposals locked onto neighbor lanes or divider reflections
(confidently wrong → the "We found the lane" hint overstates); one MISS
(falls back to default corners — the honest failure). Consistent with the
July finding; saved-calibration-primary + drag-to-adjust remains the right
call. Caveat: all six frames have a bowler occluding the near lane, which
is also true of the app's own calibration frame (first frame of a throw).
Re-evaluate on real propped-phone footage after the alley visit before
touching the detector.
