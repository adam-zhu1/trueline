# Auto calibration and handheld tracking: feasibility (Nov 18, 2026)

Two questions, tested on the accuracy benchmark corpus (8 Aug 17 alley clips
plus the portfolio throw at 30 and 60 fps, with their reference calibrations
and the 223 hand-labelled ball positions).

1. Can the app propose the lane calibration by itself, so the user only
   confirms it?
2. Can the app track the lane through a handheld clip, so the phone doesn't
   need a tripod or a prop?

## Verdicts

**Experiment 1, automatic calibration: feasible with work.** The shipping
LaneAutoDetector is not usable on real in-app footage: it made no proposal
on 6 of 10 clips and the other 4 were 270 to 450 px off (wrong lane or a
corner on the approach). A new feature fit (vanishing point, lane strip,
foul line, arrow V, pin deck, then a joint fit) found the right lane on 10
of 10 clips, with corners 5 to 9 px from the reference, 0.1 to 0.4 boards at
the arrows and 0.4 to 1.2 boards at the pins on the batch-2 and portfolio
clips. That is about as good as today's 6 landmark taps (1.8 boards median
in the Aug 25 Monte Carlo) and not as good as the refine step (0.5 to 0.7).
So "auto-propose, then the user drags the overlay onto the pins" is
realistic. The work: port it to Swift, test it in other houses (all of this
is one house), add a confidence gate, and settle the batch-1 disagreement
below.

**Experiment 2, handheld tracking: feasible with work, if registration is
to a keyframe.** In simulation, registering every frame to the calibration
frame (KLT on frame-0 features, starting from the previous estimate, RANSAC
homography) carries the calibration through 0.7 to 4 degrees of handheld
motion with entry board within 0.1 to 0.3 board of the truth, entry angle
within 0.3 degrees and launch speed within 0.1 mph, at about 3 ms a frame at
half resolution on the Mac. Chaining frame to frame drifts and is not
usable (entry off by 1 to 5 boards). Without any correction, handheld motion
destroys the metrics (entry off by 4 boards at the mildest level, unreadable
at the others). The app's detector still finds the ball in blurred handheld
renders, but its boxes get 2 to 5 px noisier, which moves entry by up to
1.4 boards; so the detector needs the blur-augmented retrain too. The rest
of the work is what simulation can't test: parallax,
rolling shutter, real blur and exposure changes, and the bowler filling the
frame. It needs one real handheld session before any build.

**Side finding, worth acting on now:** the tripod clips are not still. All
registration methods agree that the propped phone moved during every alley
throw, 3 to 18 px at the corners while the ball rolled and up to 9 boards at
the pin deck for a few frames around release. On IMG_5115 the prop sagged
7.7 px at the deck by the time the ball got there. The app already has
DriftCheck; running it within the throw, not just between throws, is cheap
(see "Real motion in the tripod clips").

## Experiment 1: automatic lane calibration

Scripts: `exp1_autocal.py` (runs everything and prints the tables below),
`lanefit.py` (the new fit). Scored against the benchmark calibrations on
frame 0 of each clip, which is clean on the alley clips; the portfolio frame
has the bowler standing over the left foul corner. Board error is the mean
over all 39 boards across the lane of |board read through the proposal -
true board|, at 15 ft and at 59.5 ft.

### (a) The existing detector

The app's Swift `LaneAutoDetector` (built with
`experiments/lane_autodetect_swift`), plus the Python prototype it was
ported from.

| Clip | Swift: corner px mean / max | arrows bd mean / max | pins bd mean / max | Python prototype: corner px | pins bd |
|---|---|---|---|---|---|
| IMG_5105 | 447 / 555 | 74.0 / 172.7 | 19.1 / 45.3 | 279 | 139.5 |
| IMG_5106 | 357 / 468 | 79.9 / 179.0 | 25.3 / 59.8 | 210 | 22.6 |
| IMG_5107 | no proposal | | | 677 | 13.7 |
| IMG_5108 | no proposal | | | 702 | 11.0 |
| IMG_5112 | no proposal | | | 602 | 17.0 |
| IMG_5113 | no proposal | | | 627 | 25.6 |
| IMG_5114 | 364 / 680 | 194.7 / 362.4 | 605 / 951 | 316 | 693 |
| IMG_5115 | no proposal | | | 251 | 154.6 |
| portfolio_30 | 271 / 302 | 7.0 / 12.4 | 10.7 / 12.4 | 356 | 66.1 |
| portfolio_60 | no proposal | | | 233 | 9.8 |

Same failure as on the Instagram clips, for two reasons. It assumes the
subject lane brackets the frame's center column, which is false whenever
the phone stands beside the lane (batch 1) or the lane is tilted (batch 2).
And it puts the pin end where the two gutter lines have converged to 18% of
their near width, which is a guess, not a feature. It never errs by less
than 200 px.

### (b) A feature fit

How `lanefit.py` works, at half resolution except where noted:

1. **Vanishing point.** LSD line segments below the masking unit, RANSAC for
   the point that the most segment length points at. Every lane edge,
   gutter, cap and board seam in the house is parallel, so they all vote.
2. **Lane strip.** Resample so every line through the vanishing point is a
   column. Lanes become vertical bright strips with dark gutters between.
   In this view every lane has the same width (it is lateral ground
   position over camera height), so width can't pick the subject lane; the
   strip covering the most image area below the vanishing point does,
   because the near lane is the one that reaches the bottom of the frame.
   The edges are then refit as free image lines from the strongest signed
   gradient on each row.
3. **Foul line.** Grid search over the line's height at each lane edge for
   the darkest continuous line across the whole lane (30th percentile of a
   black-hat response along it, so text and dots don't count).
4. **Depth and cross-lane skew.** With both edges and the foul line fixed,
   two parameters are left. Grid search (full resolution) scored by the
   arrow V (seven dark marks at boards 5 to 35, center at 15 ft, 0.5 ft
   nearer per arrow outward, gaps between them must be light) and by the
   pin deck (bright pin bodies standing on the ten pin spots), separately
   and jointly.
5. **Joint fit.** Keep the foul corners, free the two far corners and
   maximize the arrow and pin evidence together. The gutter edges are long
   and sharp near the camera but a few dozen pixels wide at the deck, so
   the pins are the better lateral reference there.

About 1.3 s per frame in Python on the M4 Max.

Results for the final fit (step 5). "pins feet" is the depth error at the
deck (negative means the proposal puts 59.5 ft nearer the camera). The last
three columns check single features against the hand landmarks from
calibration_v11 (arrow marks and head pin in px, the seven visible pin
columns read back in boards).

| Clip | corner px mean / max | arrows bd mean / max | pins bd mean / max | pins feet | foul line px | arrows px | head pin px | pin columns bd |
|---|---|---|---|---|---|---|---|---|
| IMG_5105 | 8 / 11 | 0.4 / 0.7 | 3.7 / 5.0 | -6.2 | 7 | 1 | 10 | 3.8 |
| IMG_5106 | 9 / 11 | 0.4 / 0.7 | 3.5 / 5.0 | -6.5 | 8 | 1 | 10 | 3.6 |
| IMG_5107 | 8 / 9 | 0.4 / 0.7 | 3.8 / 4.9 | -5.4 | 7 | 1 | 9 | 3.9 |
| IMG_5108 | 9 / 12 | 0.4 / 0.8 | 3.5 / 5.1 | -6.7 | 8 | 1 | 11 | 3.6 |
| IMG_5112 | 6 / 13 | 0.1 / 0.4 | 1.2 / 1.9 | -2.1 | 8 | 1 | 3 | 1.3 |
| IMG_5113 | 5 / 6 | 0.1 / 0.2 | 1.0 / 1.3 | +3.3 | 4 | 1 | 5 | 1.0 |
| IMG_5114 | 7 / 13 | 0.1 / 0.2 | 0.4 / 0.7 | +3.8 | 8 | 2 | 6 | 0.4 |
| IMG_5115 | 6 / 9 | 0.2 / 0.3 | 1.1 / 1.3 | -0.7 | 9 | 1 | 3 | 1.1 |
| portfolio_30 | 6 / 8 | 0.3 / 0.6 | 0.6 / 1.5 | -2.4 | 3 | | 8 | |
| portfolio_60 | 5 / 8 | 0.2 / 0.5 | 0.6 / 1.4 | -2.2 | 3 | | 7 | |
| median | 7 | 0.2 | 1.2 | | | | | |

The intermediate fits, for comparison (median over the 10 runs):

| Fit | corner px | arrows bd | pins bd | batch-2 + portfolio pins bd |
|---|---|---|---|---|
| edges + foul line + arrow V only | 7 | 0.3 | 1.3 | 0.5 to 1.3 |
| edges + foul line + pins only | 7 | 0.4 | 1.2 | 0.5 to 1.4 |
| joint (arrows and pins) | 7 | 0.3 | 1.3 | 0.5 to 1.3 |
| joint, far corners refit (final) | 7 | 0.2 | 1.2 | 0.4 to 1.2 |

The proposal is stable: on frames 0, 30, 60 and 90 of each clip the corners
move by 1 to 6 px, and on a frame with the bowler and ball in view (the
first labelled frame) it still finds the lane, with pins error 0.1 to 4.7
boards (worst on 5108 at 4.7, where the bowler covers the near lane).

**Which features were reliable**

- Vanishing point: 10 of 10.
- Lane strip, picking the subject lane: 10 of 10 with the image-area rule.
  The first version picked the widest strip and chose the neighbouring lane
  on all four batch-2 clips; widths are equal in this view.
- Foul line: 10 of 10, 3 to 9 px. It is the most reliable near feature:
  the painted line runs edge to edge and nothing else on the approach does.
- Arrow V: 8 of 8 alley clips within 1 to 2 px of the hand-marked arrows.
  The marks are only 3 to 4 px wide, so this has to run at full resolution;
  at half resolution with a larger kernel it locked onto board seams 40 to
  50 px off.
- Pin deck: right laterally, uncertain in depth. The pins are the brightest
  thing at the far end, but the base of each pin is ambiguous: the lower
  pin body is darker, and the glossy deck mirrors the pins below it. The
  head-pin error is 3 to 8 px on batch 2 and portfolio and 9 to 11 px on
  batch 1, and at the deck 1 px of height is about 0.3 to 0.5 ft.
- Gutter edges: good near the camera, poor as the far-end reference. Before
  the far-corner refit, the edge lines alone put the deck 1 to 6 boards off.

**The batch-1 disagreement.** On the four batch-1 clips (one camera
placement, so one result four times) the proposal and the reference agree
at the arrows (0.4 board) and disagree at the deck by 3.5 to 3.8 boards and
6 ft of depth. The lane runs diagonally across that frame, so a depth error
there is also a board error. I don't think the proposal is simply wrong
there. The accuracy benchmark already flagged the batch-1 references: the
labelled ball speeds up down the lane under them, which a real ball doesn't
do. Through the proposal the same labels give a flat speed profile:

| Clip | speed 0-20 / 20-40 / 40-58 ft, reference | same, proposal | entry, reference / proposal |
|---|---|---|---|
| IMG_5105 | 15.4 / 16.6 / 16.6 | 14.7 / 15.0 / 14.1 | 10.4 / 12.1 |
| IMG_5107 | 16.7 / 17.7 / 18.5 | 15.9 / 16.2 / 16.2 | 10.9 / 10.5 |
| IMG_5108 | 15.1 / 16.7 / 18.0 | 14.3 / 14.8 / 14.9 | 17.1 / (labels stop at 53 ft) |
| IMG_5112 | 15.9 / 16.3 / 15.3 | 15.4 / 15.5 / 14.5 | 9.1 / 12.6 |
| IMG_5113 | 15.2 / 14.6 / 13.8 | 15.7 / 15.4 / 14.9 | 19.3 / 16.0 |
| IMG_5115 | 15.4 / 15.7 / 16.3 | 15.4 / 15.7 / 15.9 | 18.6 / 20.5 |
| portfolio_30 | 17.5 / 18.5 / 18.2 | 17.4 / 17.9 / 16.8 | 16.6 / (labels stop at 54 ft) |

Neither profile slows by the expected 10 to 15%, so neither calibration is
proven right. The zoomed deck crop shows the reference's 60 ft line on the
pins' reflections, below where the bodies end, and the proposal at the
bottom of the bodies; the true base is somewhere between. The alley session
with taped boards will settle it.

**Entry board moves more than the pins error suggests.** Labels-only entry
under the proposal differs from the reference by 0.4 to 3.5 boards on the
clips where both can be read. The 59.5 ft reading point depends on the
depth scale, and the deck depth is the weakest part of the fit (2 to 4 ft
off on batch 2). So the proposal is a starting point, not a calibration.

### (c) Is "auto-propose, user confirms" realistic?

Yes, as a replacement for the six coarse taps, not for the refine step.

- **Accuracy.** On the clips where the reference is trusted, the proposal
  is 0.4 to 1.2 boards at the deck and 4 to 9 px at the corners. The Aug 25
  Monte Carlo put six landmark taps at 1.8 boards median and the overlay
  refine at 0.5 to 0.7. So the proposal skips the coarse stage, and the user
  still does the refine drag. Entry accuracy is decided by far-field
  precision, so the refine step stays.
- **Time.** Tapping six landmarks with a loupe takes about 15 to 25 s, and
  the refine drag about 10 s more. A proposal costs about 1 s of compute
  (Python here; the Swift port should be similar or faster) and one look.
- **Break-even.** The refine step is a drag of the drawn rack onto the real
  pins. It only works if the drawn rack is close enough that the user
  matches the right pin to the right pin, which is about half a pin spacing
  at the deck (6 in, about 5.6 boards, or 6 to 7 px on these clips). Up to
  that, confirming plus one drag is faster than tapping. Between half a pin
  spacing and about one lane width, the user has to drag several handles
  and it costs about what tapping does. Beyond that (the wrong lane, a foul
  line on an approach seam), the user has to recognize the mistake first,
  which is slower than tapping. The old detector was always in this last
  band. The new fit was inside the first band on every clip except the
  batch-1 placement, which is at the edge (3.5 to 3.8 boards, 9 to 11 px at
  the head pin).
- **What it needs to ship.** A confidence gate (the fit's own scores: arrow
  and pin z-scores, foul-line contrast, and agreement between the
  arrows-only and pins-only fits) that falls back to the tap flow, and a
  one-tap "this lane" hint when two strips score close. Tests in at least
  two more houses: real wood lanes, other arrow styles, darker or dimmer
  lighting, and a neighbouring lane in play.

## Experiment 2: handheld tracking

Scripts: `handheld.py` (motion model and registration), `exp2_handheld.py`
(simulation and scoring), `exp2_detector.py` (rendered video through the
app's detector), `report_exp2.py` (tables).

### (a) Motion model

Frame 0 is the calibration frame (identity). For each later frame, camera
rotation about yaw, pitch and roll is a slow drift (three sinusoids at 0.05
to 0.4 Hz, random phase) plus tremor (two sinusoids at 4 to 10 Hz), with a
slow image-space sway for the translation, rendered as one homography
W_t = T K R K^-1 (iPhone 1x camera, about 69 degrees on the long side).
Camera-motion blur averages 5 warps across a 1/(2 fps) exposure. Seed 1 for
every clip, so every clip gets the same motion.

| Level | drift per axis | tremor per axis | sway | peak rotation reached |
|---|---|---|---|---|
| mild | 0.5 deg | 0.05 deg | 3 px | 0.6 to 0.7 deg |
| moderate | 1.5 deg | 0.15 deg | 6 px | 1.9 to 2.1 deg |
| strong | 3.0 deg | 0.3 deg | 12 px | 3.8 to 4.2 deg |

Truth is W_t composed with the clip's own real motion (next section),
measured by keyframe KLT on the untouched footage. ORB and ECC agree with
it to about 0.2 board at the deck. Because the truth uses keyframe KLT, the
keyframe KLT rows below are partly scored against themselves. The ORB rows
are the independent check, and they are the numbers to quote.

### Real motion in the tripod clips

| Clip | corner px max | during the throw | at the last frame | pins board max | entry, fixed / corrected | speed, fixed / corrected |
|---|---|---|---|---|---|---|
| IMG_5105 | 10.6 | 8.7 | 1.6 | 4.84 | 10.37 / 10.79 | 15.45 / 15.49 |
| IMG_5107 | 14.1 | 11.8 | 1.1 | 6.24 | 10.90 / 11.16 | 16.74 / 16.72 |
| IMG_5108 | 17.9 | 17.9 | 2.3 | 9.07 | 17.08 / 17.71 | 15.14 / 15.16 |
| IMG_5112 | 5.3 | 5.3 | 0.9 | 1.18 | 9.09 / 8.83 | 15.90 / 15.97 |
| IMG_5113 | 6.1 | 3.2 | 2.2 | 1.17 | 19.31 / 19.72 | 15.19 / 15.19 |
| IMG_5115 | 12.7 | 9.3 | 7.9 | 5.61 | 18.64 / 15.06 | 15.36 / 15.39 |
| portfolio_30 | 3.5 | 3.5 | 0.4 | 0.09 | 16.56 / 16.76 | 17.50 / 17.48 |

The large values are brief: on 5108 the far end swings about 2.5 boards
each way over frames 220 to 235 (the ball landing) and settles about 0.4
board off. KLT on the lane, KLT on the top half, ORB and ECC all show the
same swing, so it is real. On 5115 the prop sags steadily to about 5 px at
the deck and jumps to 7.7 px when the ball lands, and stays there.
Correcting for it moves the label-only entry from 18.6 to 15.1. That
disagrees with the 17 to 18 that the pin action suggested, so 5115 needs a
look before either number is trusted.

### (b, c) Registration: errors through the clip

Methods: `klt_chain` (features on the previous frame tracked to this one,
homographies multiplied), `klt_key` (frame-0 features tracked into this
frame after warping it back by the previous estimate), `orb_key` (ORB
matched to frame 0, same warm start). Masks: `none`; `lane` (the lane, one
lane width either side, plus the band above the deck); `lane_motion` (also
excluding pixels that changed against the reference after alignment, the
bowler and ball); `far` (the lane from 20 ft on); `top` (DriftCheck's top
half of the frame). Every method rejects a per-frame correction that moves
the frame corners by more than 8% and keeps the previous estimate. ECC with
a homography was also tried. It was as accurate as KLT when it converged,
but it diverged on some frames (131 px p95 on 5108 with the lane mask) at
70 to 200 ms a frame, so it was dropped from the sweep.

Moderate motion, median over the 7 labelled clips of each clip's median and
p95 over all frames:

| Method / mask | corner px med / p95 | arrows bd med / p95 | pins bd med / p95 | worst pins bd during a throw | ms/frame |
|---|---|---|---|---|---|
| no correction | 26.8 / 55.4 | 2.25 / 6.18 | 5.40 / 16.08 | 15.49 | 0 |
| klt_chain / lane | 2.0 / 8.6 | 0.07 / 0.53 | 0.22 / 0.83 | 4.70 | 5 |
| klt_chain / lane_motion | 1.7 / 7.3 | 0.06 / 0.24 | 0.11 / 0.74 | 8.33 | 6 |
| klt_key / none | 0.1 / 0.3 | 0.01 / 0.03 | 0.03 / 0.09 | 0.43 | 3 |
| klt_key / lane | 0.1 / 0.3 | 0.01 / 0.03 | 0.03 / 0.09 | 0.58 | 3 |
| klt_key / lane_motion | 0.1 / 0.3 | 0.01 / 0.03 | 0.03 / 0.09 | 0.74 | 4 |
| klt_key / far | 0.8 / 1.7 | 0.01 / 0.04 | 0.03 / 0.09 | 12.30 | 2 |
| klt_key / top | 0.3 / 0.7 | 0.01 / 0.04 | 0.03 / 0.08 | 0.96 | 3 |
| orb_key / none | 0.8 / 3.0 | 0.04 / 0.15 | 0.10 / 0.31 | 1.98 | 12 |
| orb_key / lane | 0.7 / 3.2 | 0.04 / 0.13 | 0.09 / 0.26 | 1.34 | 12 |
| orb_key / lane_motion | 0.7 / 3.4 | 0.04 / 0.12 | 0.10 / 0.29 | 12.65 | 13 |
| orb_key / far | 6.1 / 20.5 | 0.07 / 0.24 | 0.09 / 0.28 | 12.25 | 11 |
| orb_key / top | 1.4 / 4.3 | 0.06 / 0.23 | 0.11 / 0.39 | 1.93 | 12 |

Metric error against the true per-frame calibration (mean absolute over
the 7 clips / worst clip), moderate motion. "Lost" means the metric could
not be computed at all.

| Method / mask | entry board | entry angle deg | launch speed mph | arrows board |
|---|---|---|---|---|
| no correction | lost on 7 of 7 | lost on 7 of 7 | 0.90 / 2.42 | 1.88 / 4.60 |
| klt_chain / lane | 0.88 / 2.12 | 0.61 / 0.93 | 0.23 / 0.38 | 0.38 / 1.09 |
| klt_chain / none | 1.95 / 4.69 (1 lost) | 0.39 / 0.82 | 0.15 / 0.30 | 0.48 / 2.03 |
| klt_key / lane | 0.04 / 0.11 | 0.06 / 0.21 | 0.01 / 0.03 | 0.01 / 0.02 |
| klt_key / lane_motion | 0.05 / 0.08 | 0.06 / 0.18 | 0.01 / 0.03 | 0.01 / 0.02 |
| klt_key / top | 0.04 / 0.09 | 0.06 / 0.19 | 0.01 / 0.04 | 0.01 / 0.05 |
| orb_key / none | 0.28 / 1.07 | 0.39 / 1.31 | 0.05 / 0.07 | 0.04 / 0.10 |
| orb_key / lane | 0.16 / 0.48 | 0.27 / 0.53 | 0.03 / 0.07 | 0.03 / 0.06 |
| orb_key / lane_motion | 0.19 / 0.49 | 0.25 / 0.49 | 0.06 / 0.17 | 0.02 / 0.07 |

Across motion levels, lane mask:

| Level | Method | pins bd p95 | entry board | entry angle deg | launch speed mph |
|---|---|---|---|---|---|
| mild | no correction | 5.74 | 4.09 / 7.78 (5 lost) | 0.98 / 1.31 (5 lost) | 0.29 / 0.63 |
| mild | klt_chain | 0.84 | 1.37 / 5.29 | 0.48 / 0.80 | 0.18 / 0.50 |
| mild | klt_key | 0.07 | 0.06 / 0.29 | 0.08 / 0.31 | 0.00 / 0.01 |
| mild | orb_key | 0.24 | 0.18 / 0.78 | 0.23 / 0.96 | 0.03 / 0.12 |
| moderate | no correction | 16.08 | lost on 7 | lost on 7 | 0.90 / 2.42 |
| moderate | klt_chain | 0.83 | 0.88 / 2.12 | 0.61 / 0.93 | 0.23 / 0.38 |
| moderate | klt_key | 0.09 | 0.04 / 0.11 | 0.06 / 0.21 | 0.01 / 0.03 |
| moderate | orb_key | 0.26 | 0.16 / 0.48 | 0.27 / 0.53 | 0.03 / 0.07 |
| strong | no correction | 29.64 | lost on 7 | lost on 7 | 2.20 / 6.44 |
| strong | klt_chain | 0.74 | 1.39 / 4.51 | 0.46 / 0.90 | 0.13 / 0.25 |
| strong | klt_key | 0.13 | 0.08 / 0.19 | 0.12 / 0.32 | 0.02 / 0.04 |
| strong | orb_key | 0.25 | 0.11 / 0.40 | 0.19 / 0.55 | 0.04 / 0.09 |

For scale, the tripod pipeline's own error against the labels is 0.43
board entry, 0.21 degrees and 0.18 mph (accuracy benchmark, Nov 15), and a
user's calibration adds 0.5 to 0.7 board at the deck. Keyframe registration
adds well under either in simulation.

What the tables say:

- **Keyframe beats chaining, by a lot.** Chained homographies look fine on
  a median frame but accumulate error; by the time the ball reaches the
  pins the deck is off by up to 5 to 8 boards on some clips, and entry by
  up to 5. Registering to frame 0 every frame, warm-started from the last
  estimate, has nothing to accumulate.
- **Uncorrected handheld footage is unusable.** Even mild motion (under
  0.7 degrees) moves entry by 4 boards on average.
- **Masks matter less than expected in simulation, and some hurt.** The
  plain lane mask is the best or tied for best everywhere. The `far` mask
  extrapolates badly to the near lane (corner error 0.8 to 6 px) and lost
  the lock on a few frames. Motion masking did not help keyframe KLT, and
  for ORB it occasionally removed the good features at release (worst
  frame 12 boards). In simulation the bowler moves against a homography
  that every static pixel obeys exactly, so RANSAC removes the bowler
  without help. With real parallax this may change (see (e)).
- **ORB is 3 to 4 times slower and 3 to 5 times less precise than KLT**
  here, but it is the method that is not scored against itself, and it
  still keeps entry within 0.5 board.
- **Cost.** KLT keyframe registration is 3 ms a frame at 540 x 960 on the
  Mac (OpenCV). On the phone, Vision's homographic registration (what
  DriftCheck already uses, about 10 ms on the Mac at half resolution) on
  every frame of a 10 s clip would add about 3 s at 30 fps, before
  analysis. Registering every 2nd or 3rd frame and interpolating would be
  the first thing to try.

### (d) Ball detection under motion and blur

Tested with the app's own ShotAnalyzer and Core ML model through the
accuracy benchmark's Swift harness, on full-resolution renders of four
clips (x264 crf 14; "still" is the same encode with no motion, so codec loss
cancels). The harness only takes one set of corners, so it gets the frame-0
corners. The `tremor_*` variants are tremor only (0.15 or 0.3 degrees, the
lane stays within a few pixels), which tests the detector under blur
without moving the lane box. "det px" is the detector box centre against
the label carried into the moving frame. "Entry/speed from boxes" maps the
detector boxes back through the true motion, so calibration is excluded,
and applies the label-metric rules.

| Clip / variant | tracked (measured) | raw boxes | labels detected (within 1 r) | det px median | entry from boxes | speed from boxes | app entry / speed, fixed corners |
|---|---|---|---|---|---|---|---|
| IMG_5108 still | 74 (74) | 91 | 43/43 (43) | 0.7 | 17.18 | 14.84 | 17.4 / 15.3 |
| IMG_5108 tremor 0.15 | 74 (74) | 98 | 43/43 (43) | 2.4 | 17.27 | 14.82 | -- / 15.3 |
| IMG_5108 tremor 0.3 | 1 (1) | 8 | 0/43 | -- | -- | -- | -- / -- |
| IMG_5108 moderate | 89 (89) | 91 | 43/43 (43) | 2.2 | 17.55 | 14.87 | -- / 15.4 |
| IMG_5108 strong | 89 (89) | 91 | 43/43 (42) | 4.5 | 17.82 | 14.89 | -- / 15.4 |
| IMG_5113 still | 82 (73) | 82 | 27/28 (27) | 1.5 | 14.42 | 15.04 | 19.0 / 15.0 |
| IMG_5113 tremor 0.15 | 85 (76) | 82 | 28/28 (28) | 3.3 | 13.25 | 14.97 | -- / 15.0 |
| IMG_5113 tremor 0.3 | 83 (76) | 82 | 28/28 (24) | 6.2 | 12.81 | 14.88 | -- / 14.9 |
| IMG_5113 moderate | 79 (76) | 82 | 28/28 (28) | 3.2 | 12.71 | 15.09 | -- / 11.8 |
| IMG_5113 strong | 79 (75) | 87 | 27/28 (23) | 5.5 | 11.38 | 15.22 | -- / 7.0 |
| IMG_5115 still | 71 (70) | 71 | 25/25 (25) | 1.8 | 17.32 | 15.54 | 18.2 / 15.6 |
| IMG_5115 tremor 0.15 | 70 (69) | 69 | 25/25 (25) | 3.1 | 17.25 | 15.50 | -- / 15.6 |
| IMG_5115 tremor 0.3 | 70 (69) | 71 | 25/25 (23) | 4.7 | 16.53 | 15.44 | -- / 15.7 |
| IMG_5115 moderate | 76 (72) | 73 | 25/25 (25) | 2.5 | 16.22 | 15.53 | 31.0 / 14.2 |
| IMG_5115 strong | 77 (73) | 76 | 25/25 (23) | 4.3 | 15.88 | 15.56 | 39.0 / 12.0 |
| portfolio_30 still | 69 (55) | 57 | 19/21 (19) | 1.4 | 16.19 | 17.19 | 16.6 / 17.7 |
| portfolio_30 tremor 0.15 | 69 (56) | 59 | 19/21 (19) | 3.5 | 15.90 | 17.04 | 16.3 / 17.5 |
| portfolio_30 tremor 0.3 | 68 (58) | 59 | 20/21 (20) | 6.7 | 15.46 | 17.14 | 15.7 / 17.5 |
| portfolio_30 moderate | 72 (55) | 56 | 20/21 (20) | 4.0 | 15.58 | 17.19 | 30.4 / 16.4 |
| portfolio_30 strong | 78 (60) | 63 | 20/21 (20) | 6.6 | 15.02 | 17.17 | 39.0 / 14.9 |

- **The detector still finds the ball.** Coverage of the labelled frames
  is the same as on the still copy in 15 of 16 motion runs. The exception,
  5108 with 0.3 degree tremor, produced only 8 boxes in the whole clip,
  while the same clip with stronger full motion was fine. I didn't find
  the cause; it needs a rerun with another seed before it counts as a
  detector failure.
- **But the boxes get noisier.** Median box error grows from 0.7 to 1.8 px
  (still) to 2.2 to 3.5 px (0.15 degree tremor) and 4.3 to 6.7 px (0.3
  degree). At the deck that is 1 to 3 boards per box. Launch speed doesn't
  care (within 0.2 mph, it averages many near-lane boxes), but entry board
  from the boxes moves by 0.1 to 1.4 boards on 5108, 5115 and portfolio,
  growing with blur. 5113's box entry is not trustworthy even on the still
  copy (it reads the pin deflection, as in the benchmark notes), so ignore
  its trend.
- **Fixed corners plus handheld is broken, even with tremor alone.** The
  app's own entry failed or read 30 to 39 on every moving clip except two
  portfolio tremor runs. Per-frame calibration is required, not optional.

So blur is the second problem after registration: a handheld clip needs
the shortest exposure the light allows, and the far-lane box error would
have to come down (a blur-augmented retrain, which the detector retraining
plan already lists as augmentations that never ran).

### (e) What simulation can't show

- **Parallax.** A handheld phone translates by centimetres. The lane plane
  stays a homography, but the pins, the masking unit, the ball return and
  the bowler sit off the plane and move differently. The `top` and `far`
  masks (which lean on the masking unit and the pin deck) would suffer
  most, and the plain lane mask would need to be restricted to features on
  the lane surface. A 2 cm sideways move at a 20 m deck is 0.06 degrees,
  small; the same move against the ball return 1 m away is 1 degree, not
  small.
- **Rolling shutter.** iPhone sensors read out over about 10 to 20 ms. Fast
  tremor then bends the frame (a skew or wobble), which no single
  homography models. The deck and the foul line are read at different
  times within a frame.
- **Real blur, focus and exposure.** Here blur is camera motion averaged
  over a fixed exposure. A real phone in an alley picks longer exposures
  under poor light, refocuses when the bowler walks in, and changes
  exposure as the bowler's shirt fills the frame. Each of these breaks
  intensity matching against frame 0 more than geometry does.
- **Glossy lanes.** The lane mirrors the lights and the pins, and
  reflections move with the camera, not with the lane. In simulation they
  are painted on.
- **The bowler.** Handheld means someone is holding the phone, likely from
  behind the bowler, so the bowler may cover more of the near lane than on
  the tripod clips.
- **Stabilization.** The iPhone's own video stabilization will already
  remove much of the tremor, and it crops and warps the frame differently
  for each frame, which also breaks the single-homography assumption.

**What a real handheld test clip needs to show.** Record on a session with
taped boards and a speed reading, so there is truth that doesn't come from
the pipeline:

1. Three throws each: tripod (control), braced handheld (elbows on a table
   or the ball return), free handheld standing behind the approach, and a
   friend holding the phone while walking a step. Both with and without
   the camera's stabilization if the app can choose.
2. Calibrate on the first frame of each clip, with the tap flow.
3. A static check: a few seconds of holding still with nobody on the lane,
   so registration error can be measured with no moving objects.
4. The full lane in frame including the deck at all times, with the
   phone held portrait, the way the app asks for it.
5. Lighting as it is at league time, and at least one throw while the
   neighbouring lane is bowling.
6. What to read from it: per-frame deck motion and the NCC after alignment
   (as in DriftCheck), detector coverage compared with the tripod throw,
   and entry board, angle and speed against the taped truth. Pass if the
   handheld numbers land within the tripod numbers' spread plus 0.5 board.

## Files

- `common.py` shared helpers (benchmark clips, board error at a depth).
- `lanefit.py` the new auto-calibration.
- `exp1_autocal.py` experiment 1; `--overlays` writes overlay images to
  `out/`, `--stability` runs the other-frames check.
- `handheld.py`, `exp2_handheld.py`, `exp2_detector.py`, `report_exp2.py`
  experiment 2.

Run from the repo root with `.venv/bin/python`. Outputs land in `out/`
(git-ignored). Videos are read from the main checkout's data/ tree; the
detector test writes its rendered videos to the system temp folder and
deletes them.
