# Rev-rate experiment — tape-flash FFT

The plan from the Aug 30 LaneTrax research: put a strip of white tape on
the ball running from the PAP out past the finger holes (not a patch at
the PAP itself: that's the spin pole and barely moves), and the tape sweeping through the camera-facing
hemisphere once per revolution makes the ball patch's mean brightness a
periodic signal. Rev rate = the fundamental frequency. This harness is
built and validated ahead of the ground-truth alley session so the taped
clips can be analyzed the day they're shot.

## Pipeline

1. `extract_signal.py <video> <track.json>` — mean grayscale over a disc
   inside the ball (track format = calibration_v11 detections; the y is
   the contact point, disc sits one radius up) plus a background annulus,
   per tracked frame → `signals/<clip>_signal.json`.
2. `estimate_rpm.py signals/<clip>_signal.json` — normalize by
   background, interpolate gaps, detrend, harmonic-weighted FFT peak in
   90-540 RPM, parabolic refinement. Confidence needs split-half
   consistency (mandatory — FFT and autocorrelation see the same noise,
   halves are the only independent check) plus autocorrelation agreement
   or strong SNR, and >=60% real detection coverage.
3. `synth_test.py` — the validation gate. Run it after any estimator
   change; it must exit 0.

## Validation status (Sep 2)

- **Synthetic:** 22/22 gated recoveries within ±12 RPM across 150-450 RPM
  x 30/60 fps x realistic tape amplitudes; 2/200 null false positives
  (gate <=1%); every confident answer in the marginal tier was accurate.
  Documented 30 fps floors: 450 RPM leaves 4 samples/rev, 150 RPM too few
  periods per half-window — both only at elevated noise. 60 fps (the
  field-test capture rate) has no floor cases.
- **Real clips (all untaped):** batch-2 correctly refused at 16-58%
  detection coverage (the known placement-sensitivity gap). Batch-1 was
  expected to be a null test and was NOT: 5105/5106/5107/5108 read a
  consistent 344-385 RPM (5108, the strike with the cleanest track,
  passes the full confidence gate at 344). The ball's graphic appears to
  act as a natural marker through motion blur — patch-mean flash survives
  blur that killed marker-tracking CV. If the 240 fps truth confirms it,
  marker-less rev rate may be viable for balls with a visible logo.

## Nov 2026 changes (from notes/rev-rate-research.md)

- **Early lane only.** The window is now 1.2 s from the first detection
  (about the first 25 to 30 ft), stretched up to 1.8 s so a low-rev ball
  still fits 5 revolutions. Rev rate climbs 10 to 50% down the lane once
  the ball leaves the skid, so the old 2.2 s window read high.
- **Refusals.** No answer when the window holds fewer than 3 revolutions,
  the median ball radius is under 20 px, the reading is above 420 RPM at
  30 fps (record at 60 fps), or outside 120 to 600 RPM.
- **SNR floor 3.2** (was 2.8). The shorter window halves the samples, and
  at 2.8 the null false positive rate crept above 1%.
- **Synthetic gate is now a recovery rate per capture rate**: 120 fps
  87% (need 85%), 60 fps 100% on clean signals (need 80%), 30 fps 75%
  (reported only), zero confident-but-wrong answers, 0/200 null passes.
- **Real clips:** 5105-5108 now all read confident at 328 / 353 / 380 /
  350 RPM. The old late-lane false positive (5105 at 109) is gone. 5112-5115
  are refused (sparse tracks, or a 20 px ball on the tilted 5115).

## Caveats for the alley session

- **Flashes per rev is assumed = 1.** One tape strip; a symmetric graphic
  or a second bright patch would double the reading. The 240 fps
  hand-counted revs adjudicate exactly this before any number is trusted.
- 30 fps caps reliable detection at ~450 RPM; the field-test build's
  60 fps is comfortably clear. Prefer it for the taped set.
- Estimates need decent tracks: the coverage gate will refuse clips where
  detection dies early (tilted placement), same as batch-2 here.

## After the session

Run extract + estimate on each taped clip, hand-count revs in the slow-mo
clips, and compare. FFT within ~10 RPM of the hand count across 5 throws
= rev rate graduates from experiment to metric candidate.
