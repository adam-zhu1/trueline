# Accuracy benchmark, November 2026

Written Nov 15. A repeatable benchmark for the shipping tracker, a set of
hand-checked ball positions to score it against, and what the first runs say.

## What it is

`experiments/accuracy_bench/` runs the app's own Analysis sources (compiled
on the Mac with `main.swift`, the same files the app builds) over every clip we
have both footage and a trusted calibration for, then scores the result.

```bash
# from the repo root; .venv has numpy + opencv
.venv/bin/python experiments/accuracy_bench/bench.py run --tag <name>   # build, run, score
.venv/bin/python experiments/accuracy_bench/bench.py score --tag <name>
.venv/bin/python experiments/accuracy_bench/bench.py compare <before> <after>
```

A run takes about 45 s for all ten clips on the M4 Max. Results land in
`experiments/accuracy_bench/out/<tag>.json` (git-ignored): every metric, the
gate counts, and a per-frame trace (Kalman state, the detector box, the
refined measurement, board and feet). The trace comes from a new
`ShotResult.trace` (`AnalysisTrace.swift`), which the app ignores.

### Corpus (10 runs, 9 throws)

| Clip | Source | Calibration |
|---|---|---|
| IMG_5105, 5106, 5107, 5108 | Aug 17 alley, batch 1 placement, 1080p 30 fps | calibration_v11 references (landmark fit) |
| IMG_5112, 5113, 5114, 5115 | Aug 17 alley, batch 2 (re-propped and tilted each throw) | calibration_v11 references |
| portfolio_30 | Sep 9 screen recording, 30 fps conversion | Adam's 6-landmark taps (portfolio handoff) |
| portfolio_60 | the same throw at its original 60 fps | same |

The June and July clips have no calibration anymore (data/calibration.json is
the Aug 17 legacy one) and the Aug 15 import clips are not on this Mac, so
they are not in the corpus. The references are the best calibrations we have,
which is the point: this benchmark measures tracking and metric math, not
calibration. See "What the labels can't see" below.

## Ground truth: hand-checked ball positions

There is no measured truth (no tape marks, no speed display) for any of this
footage, so I made a labelled set.

**Method** (`label_sheets.py`, `make_labels.py`, labels in `labels.json`):

1. For every other traced frame of seven clips, plus every frame past 42 ft,
   cut a square crop around the ball and fit a circle to its silhouette:
   64 rays from the crop centre, the strongest luminance step between 0.45 r
   and 1.7 r on each ray, a least-squares circle, rays more than 2.5 MAD off
   the circle dropped, three re-centring rounds. This is a different method
   from both the detector (a learned box) and the app's refineCenter (a luma
   centroid).
2. Automatic checks: at least 44 of 64 rays on the circle, rms under
   0.08 r + 0.6 px, radius within 25% of the ball size the calibration
   predicts at that depth (8.6 in ball on a 41.5 in lane). These reject the
   hand and arm occlusions near release and the frames where the ball is
   among the pins.
3. I looked at every overlay sheet for the far lane and a sample of the
   rest (about 20 sheets, 120 proposals) with the fitted circle drawn on a
   zoomed, gridded crop. The automatic checks had already rejected every
   proposal I would have rejected but three, and those three are rejected
   by name in `labels.json` (5107 f280 circle 1 px high, 5112 f459 ball
   touching a pin, 5113 f323 ball among falling pins).

Result: 223 labels on 7 clips (17 to 43 per clip, 101 of them past 40 ft),
347 proposals in total. On the far-lane balls the accepted circles fit the
edge to 0.3 to 0.5 px rms.

**What the labels measure.** Each label gives the ball's centre and radius
in display pixels. The scorer maps both the label and the tracker through the
same calibration and the same contact rule (centre plus radius straight down
on screen), so the difference is tracking and estimation error only. On top
of per-frame errors, the scorer computes each metric from the labels alone:

- arrows: where the labelled path crosses the arrow V;
- entry board and angle: a quadratic through labels from 45 ft (6+ labels,
  last one at 55 ft or deeper), read at 59.5 ft;
- launch speed: a least-squares feet-per-second slope over labels in the
  first 20 ft.

## Baseline (v1.1 at d26df02)

| Clip | Tracked fr (meas/coast) | Depth ft | Raw boxes | Lane rej | Low-conf rej | Assoc rej | Speed | Arrows | Breakpt | Entry bd | Entry ° |
|---|---|---|---|---|---|---|---|---|---|---|---|
| IMG_5105 | 76 (76/0) | 2.1-58.9 | 83 | 7 | 0 | 0 | 14.6 | 8.7 | 4.3 | 11.6 | 2.8 |
| IMG_5106 | 80 (71/9) | 1.8-59.5 | 72 | 1 | 0 | 0 | 14.6 | 6.5 | 0.0 | 0.0 | 0.0 |
| IMG_5107 | 70 (70/0) | 2.5-59.6 | 72 | 2 | 0 | 0 | 15.4 | 10.1 | 7.3 | 11.9 | 2.0 |
| IMG_5108 | 74 (74/0) | 2.3-59.3 | 82 | 8 | 0 | 0 | 12.8 | 11.4 | 11.4 | 17.9 | 1.8 |
| IMG_5112 | 75 (57/18) | 6.3-59.7 | 58 | 0 | 1 | 0 | 20.6 | 10.7 | 4.3 | 12.3 | 4.9 |
| IMG_5113 | 85 (74/11) | 4.8-59.0 | 77 | 0 | 3 | 0 | 18.8 | 8.1 | 6.5 | 11.2 | -5.3 |
| IMG_5114 | 18 (12/18) | 49.1-59.1 | 13 | 0 | 1 | 0 | -- | 11.1 | 14.0 | 16.0 | 1.0 |
| IMG_5115 | 71 (70/1) | 7.6-59.3 | 71 | 0 | 1 | 0 | 16.2 | 10.0 | 8.4 | 19.0 | 4.8 |
| portfolio_30 | 69 (55/14) | 3.0-59.4 | 56 | 1 | 0 | 0 | 16.0 | 13.4 | 5.5 | 16.4 | 4.4 |
| portfolio_60 | 136 (113/23) | 3.0-59.7 | 114 | 0 | 1 | 0 | 13.6 | 13.3 | 5.7 | 16.4 | 4.5 |

Every clip now tracks to 59 ft. 5114 is still only 18 frames (the bowler
stands between the phone and the lane until 49 ft), and is the one clip
with no usable launch speed.

### Metrics against the labels

| Clip | Arrows app / labels | Entry app / labels | Entry angle app / labels | Launch speed app / labels |
|---|---|---|---|---|
| IMG_5105 | 8.7 / 8.5 | 11.6 / 10.4 | 2.8 / 3.5 | 14.6 / 15.4 |
| IMG_5107 | 10.1 / 9.8 | 11.9 / 10.9 | 2.0 / 2.4 | 15.4 / 16.7 |
| IMG_5108 | 11.4 / 11.1 | 17.9 / 17.1 | 1.8 / 2.0 | 12.8 / 15.1 |
| IMG_5112 | 10.7 / 10.3 | 12.3 / 9.1 | 4.9 / 3.3 | 20.6 / 15.9 |
| IMG_5113 | 8.1 / 8.1 | 11.2 / 19.3 | -5.3 / 4.5 | 18.8 / 15.2 |
| IMG_5115 | 10.0 / 9.8 | 19.0 / 18.6 | 4.8 / 4.1 | 16.2 / 15.4 |
| portfolio_30 | 13.4 / 13.5 | 16.4 / 16.6 | 4.4 / 5.7 | 16.0 / 17.5 |

Mean absolute error: arrows 0.21 boards (max 0.40), entry board 2.13
(max 8.1), entry angle 2.09 degrees (max 9.8), launch speed 2.16 mph
(max 4.7). The 30 and 60 fps copies of one throw read 16.0 and 13.6 mph.

### Per-frame position error

| Zone | Labels | Kalman px | Kalman board (p90) | Refined px | Refined board | Box px | Box board (p90) |
|---|---|---|---|---|---|---|---|
| 0-10 ft | 17 | 9.4 | 0.10 (0.90) | 5.6 | 0.33 | 1.4 | 0.12 (0.27) |
| 10-20 ft (arrows) | 40 | 11.0 | 0.32 (0.47) | 2.7 | 0.22 | 1.4 | 0.10 (0.26) |
| 20-40 ft | 65 | 6.2 | 0.34 (0.62) | 1.6 | 0.31 | 1.0 | 0.12 (0.35) |
| 40-50 ft | 43 | 3.1 | 0.43 (0.93) | 1.9 | 0.46 | 1.3 | 0.30 (0.61) |
| 50-60 ft (pins) | 58 | 2.8 | 0.51 (1.09) | 2.5 | 0.91 | 1.2 | 0.34 (0.75) |

"Kalman" is the tracker state the metrics were computed from, "Refined" is
the measurement fed to the filter (detector box through refineCenter),
"Box" is the detector's own box. Boards are at the contact point.

### What the baseline says

1. **The detector is better than the tracker built on it.** The raw box
   centre sits 1.0 to 1.4 px from the label everywhere on the lane. Every
   step after it makes the position worse: refineCenter doubles the far-lane
   error (1.2 to 2.5 px, 0.34 to 0.91 boards), and the Kalman state lags the
   ball by 10 px at release and 3 px at the pins, because the filter starts
   at zero velocity and its input is also exponentially smoothed.
2. **Launch speed was the weakest number.** It was timed between two
   crossings of the Kalman feet series in the first 6 ft after lock, exactly
   where the filter lag is largest. Error 0.8 to 4.7 mph, in both
   directions, and 2.4 mph apart on the same throw at 30 and 60 fps.
3. **Entry board read high on every batch-1 clip** (+0.8 to +1.2) and failed
   outright on 5113. The tail slope was taken over the last sixth of a lagged
   track and projected from its last point; and on 5113 the last frames were
   coasted predictions plus the ball's deflection off the pins, which turned
   a 19.3 entry into 11.2 at -5.3 degrees.
4. **Arrows were already fine** (0.2 board): mid-lane the lag runs along the
   path, not across it.
5. **IMG_5115** (the Nov 1 open question, then 20.4): the tracker now reads
   19.0 and the labels 18.6. The remaining gap to the pin action Adam saw
   (about 17 to 18) is the clip's calibration, not tracking.

### What the labels can't see

The labels share the calibration with the app, so calibration error is
invisible to them. One sign that it matters: on the batch-1 clips the
*labelled* ball speeds up down the lane (5108: 15.1 mph over 0-20 ft,
16.7 over 20-40, 18.0 over 40-58; 5105 and 5107 the same shape). A real ball
slows by 10 to 15 percent. So the batch-1 references stretch far-lane feet
relative to near-lane feet by something like 15 to 20 percent. Batch 2 and
the portfolio clip are flatter. This moves speeds and breakpoint distance
more than boards, but only the alley session can size it (see the addendum
in alley-visit-checklist.md).

## Change: metrics from the detector boxes (Nov 15)

The tracker keeps doing what it does well (holding the lock, coasting
through gaps, the focus crop). The metrics stop reading its lagging state.

- **Metric series** = measured frames only, each at its raw detector box
  (centre and box radius). Coasted frames are predictions and no longer
  count. The video trail still draws the Kalman path.
- **Launch speed** = least-squares slope of feet against time over the first
  16 ft of that series (start within 15 ft, 5+ samples, 6+ ft span), in
  place of two crossings 6 ft apart on the Kalman series.
- **Entry board and angle** = one fit through the series from 40 ft to
  59.5 ft, read at 59.5 ft: a quadratic when there are 8+ samples over
  10+ ft (kept only while it stays within 3 boards of the line and under
  3 boards/ft), a line otherwise. The window is cut where the ball deflects
  off the pins: two samples in a row more than 0.6 board back from the
  furthest point toward the pocket.
- Arrows, breakpoint, hook factor, launch angle and the lane-view path run
  on the same series with their old rules.

Tracking is untouched: tracked frames, depth and gate counts are identical
on all 10 runs.

### Before and after

| Clip | Speed (labels) | Arrows (labels) | Breakpt | Entry bd (labels) | Entry ° (labels) |
|---|---|---|---|---|---|
| IMG_5105 | 14.6 → 15.7 (15.4) | 8.7 → 8.4 (8.5) | 4.3 → 4.4 | 11.6 → 10.9 (10.4) | 2.8 → 3.5 (3.5) |
| IMG_5106 | 14.6 → 16.2 | 6.5 → 6.1 | 0.0 → -0.1 | 0.0 → 0.0 | 0.0 → 0.0 |
| IMG_5107 | 15.4 → 16.4 (16.7) | 10.1 → 9.6 (9.8) | 7.3 → 7.1 | 11.9 → 11.4 (10.9) | 2.0 → 2.3 (2.4) |
| IMG_5108 | 12.8 → 15.3 (15.1) | 11.4 → 11.0 (11.1) | 11.4 → 11.1 | 17.9 → 17.4 (17.1) | 1.8 → 2.2 (2.0) |
| IMG_5112 | 20.6 → 15.8 (15.9) | 10.7 → 10.4 (10.3) | 4.3 → 5.1 | 12.3 → 9.8 (9.1) | 4.9 → 3.0 (3.3) |
| IMG_5113 | 18.8 → 15.1 (15.2) | 8.1 → 7.9 (8.1) | 6.5 → 6.6 | 11.2 → 19.7 (19.3) | -5.3 → 5.1 (4.5) |
| IMG_5114 | -- → -- | 11.1 → 10.4 | 14.0 → 11.4 | 16.0 → 17.4 | 1.0 → 4.0 |
| IMG_5115 | 16.2 → 15.6 (15.4) | 10.0 → 9.9 (9.8) | 8.4 → 8.8 | 19.0 → 18.2 (18.6) | 4.8 → 4.1 (4.1) |
| portfolio_30 | 16.0 → 17.6 (17.5) | 13.4 → 13.3 (13.5) | 5.5 → 5.7 | 16.4 → 16.7 (16.6) | 4.4 → 5.9 (5.7) |
| portfolio_60 | 13.6 → 17.7 | 13.3 → 13.3 | 5.7 → 5.6 | 16.4 → 16.5 | 4.5 → 5.7 |

| Metric vs labels (7 clips) | Before mean / max | After mean / max |
|---|---|---|
| Arrows (boards) | 0.21 / 0.40 | 0.15 / 0.23 |
| Entry board (boards) | 2.13 / 8.11 | 0.43 / 0.71 |
| Entry angle (degrees) | 2.09 / 9.76 | 0.21 / 0.64 |
| Launch speed (mph) | 2.16 / 4.65 | 0.18 / 0.31 |

Consistency check with no labels involved: the 30 and 60 fps copies of the
portfolio throw now read 17.6 / 17.7 mph (was 16.0 / 13.6) and entry
16.7 / 16.5 at 5.9 / 5.7 degrees. Batch-1 and batch-2 launch speeds, the
same bowler on the same lane, now sit in one band (15.1 to 16.4) where they
were 12.8 to 20.6.

Unit tests: `ShotMetricFitTests` (12 tests, 13 cases: exact speed at 30 and 60 fps,
jitter averaging, the 16 ft window, mid-lane and short tracks refused, a
curving back end read exactly at 59.5 ft, short-track projection, the 5113
deflection pattern, noise not mistaken for deflection, falling boards,
shallow tracks refused, the polynomial fit).

### Read these numbers with care

- **The label metrics are not independent of every choice.** The entry and
  speed estimators were picked on these same 7 clips (no held-out set), and
  the label-side entry uses the same quadratic family as the app, which
  flatters the angle agreement. Other reasonable variants land close by
  (entry error: line from 45 ft 0.54, line from 50 ft 0.38, quadratic from
  40 ft 0.44 boards; all far below the old 2.13), so the gain does not hang
  on the exact choice.
- **Breakpoint has no truth** and moved by up to 2.6 boards on 5114 (18
  tracked frames, all past 49 ft, so it never had a real breakpoint).
- **Entry still reads 0.3 to 0.7 board high on 5 of 7 clips.** The detector
  box sits about 1 px behind the ball's direction of travel at the far end
  (batch 1: 1.0 to 1.3 px left of the label while the ball moves right;
  batch 2: 0.4 to 0.8 px right while it moves left). That is 0.3 to 0.6
  board at the pins. It could be motion blur or the label method; I didn't
  correct it without truth that doesn't come from this pipeline.
- **Calibration is outside this benchmark** (see "What the labels can't
  see"). These errors are what the app adds on top of a reference-quality
  calibration. A user's 6-tap calibration adds its own (the Aug 25 Monte
  Carlo: about 0.5 to 0.7 board median at the deck after the refine step).

## What didn't work

- **Feeding the raw box to the Kalman filter** (skipping refineCenter, which
  the labels say makes positions worse). 5112 lost its lock at 41.6 ft
  (75 to 46 tracked frames): with the box radius, the focus-crop trigger and
  gate sizing changed and the far-lane rescue stopped firing. Reverted;
  refineCenter stays as tracker input only, where its bias doesn't reach
  the numbers.
- **A camera model from the homography** (focal length from the plane's
  orthogonality and equal-scale constraints, to lift the ball centre to its
  true height instead of adding the box radius). The two constraints
  disagree by 20% on batch 1 (f 1400 vs 1690 px) and go wild on 5115 and
  the portfolio clip, so the four corners can't support it. The contact
  rule's own error is small anyway (under 2 px near the foul line, nothing
  at the pins), so I dropped it.
- **Silhouette segmentation for labels** (colour distance to the lane, then
  to the ball). Merged the ball with pins and the pin deck at the far end.
  The radial edge fit replaced it.

## Recommendations, in order

1. **Size the calibration's depth error at the alley** (the batch-1 ball
   "speeding up"). It is now the largest error left in speed and probably in
   breakpoint distance. Addendum in alley-visit-checklist.md.
2. **Retrain or fine-tune with the 2x footage before chasing sub-board
   detector bias.** At 1x the ball is 9 px in radius at the pins and 2.3 px
   per board; 2x doubles both, and every remaining pixel-level error halves
   in boards.
3. **Make the tracker's own position honest** if the trail or live path
   ever feeds a number: initialise the Kalman velocity from the first two
   measurements and drop the extra exponential smoothing. Do it with the
   benchmark open: the first attempt at touching tracker input broke 5112.
4. **Grow the labelled set** with the alley-session clips (same scripts:
   `label_sheets.py --overlay`, review, `make_labels.py`), keeping the
   session's taped-board and speed-display truth alongside.
