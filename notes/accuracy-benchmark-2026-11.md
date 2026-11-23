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
