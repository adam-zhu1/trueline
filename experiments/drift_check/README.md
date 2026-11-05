# Drift check prototype (Nov 1, 2026)

The question: if the phone gets bumped between throws, can the app notice on
its own and either fix the calibration or ask for a new one?

Answer so far: yes for small bumps, and it reliably refuses big ones. Vision's
homographic registration on the top half of the frame carries the old
calibration onto the new throw to within about 1 px at the pin deck. The
entry board then reads within 0.3 board of the correct value, where the stale
calibration was off by up to 2.6 boards.

The app's version of this is `ios/Trueline/Trueline/Analysis/DriftCheck.swift`
(homography mode, same band, thresholds and score). Frames and the built
binary aren't committed; extract frames with ffmpeg from the alley clips.

## How it works

1. Keep a reference frame from when the calibration was made.
2. For each throw, take its first frame. Crop both to the top 50% of the
   portrait image: far lane, pin deck, masking unit and ceiling. The bowler
   and the approach are never in this band.
3. Downscale to 0.5 and run `VNHomographicImageRegistrationRequest` (about
   10 ms on the Mac). Invert the result so it maps reference pixels to throw
   pixels, in top-left image coordinates.
4. Verify: sample the throw through the estimate and compute normalized
   cross-correlation (NCC) against the reference band at 0.25 scale. A wrong
   estimate leaves the images misaligned and the score drops.
5. Apply the transform to the calibration points.

`main.swift` modes:

- `reg ref.png tgt.png frac [refcal tgtcal [out]]`: register a real pair, and
  optionally compare against the target's own calibration.
- `synth ref.png frac dx dy rotDeg scale`: register against a warped copy with
  a known transform.
- `synthcal frame.png frac dx dy rotDeg scale cal stale.json corrected.json`:
  write a stale and a corrected calibration for the parity harness.
- `DRIFT_MODE=homog|tiles|trans` picks the estimator; the default is tiles.
  `DRIFT_SCALE` sets the downscale.

## Results

Data: the 8 alley clips from Aug 17.

- Batch 1 (5105-5108) is one phone placement. The per-clip reference
  calibrations differ by 1-5 px.
- Batch 2 (5112-5115) was re-propped before every clip. The corners move
  70-170 px between clips, and 730 px between the two batches.

### Synthetic drift on 5105 (homography, top 50% band)

Error at the deck after correction:

| Drift | Error at deck |
|---|---|
| 20 px shift | 0.03 px |
| 15 px vertical shift | 0.4 px |
| 1 degree roll | 0.1 px |
| 2% zoom | 0.4 px |
| 10 px shift + 2 degree roll | 1.6 px |

Extrapolating to the foul line, which is outside the band, is worse: up to
10 px in one case. That matters less, because the deck is where entry board
is measured.

The band size matters. 50% beat 60% and 70%: the larger bands reach the
bowler and the near lane.

### Entry board with stale vs corrected calibration (parity harness, stage build)

Synthetic bumps applied to the true calibration, then corrected by
registering the frames:

| Clip | Bump | True | Stale | Corrected |
|---|---|---|---|---|
| 5108 | 6,4 px | 18.0 | 20.6 | 18.1 |
| 5108 | 0.7 deg roll | 18.0 | 18.6 | 18.0 |
| 5108 | -10,5 px, 1 deg, 1% zoom | 18.0 | 17.9 | 18.0 |
| 5108 | 3,-2 px, 0.3 deg | 18.0 | 19.6 | 18.2 |
| 5105 | 6,4 px | 11.7 | 14.1 | 11.7 |
| 5105 | 0.7 deg roll | 11.7 | 12.2 | 11.7 |
| 5105 | -10,5 px, 1 deg, 1% zoom | 11.7 | 9.1 | 11.6 |
| 5105 | 3,-2 px, 0.3 deg | 11.7 | 13.3 | 11.9 |

A 4 px bump moves entry board by 1.6 boards. Small bumps matter, so the
check should run on every throw, not only when the motion looks big.

Real pairs, carrying 5105's calibration onto later batch-1 throws:

| Clip | Own calibration | 5105 stale | 5105 corrected |
|---|---|---|---|
| 5107 | 12.4 | 11.3 | 12.7 |
| 5108 | 18.0 | 16.9 | 18.3 |

5106 is a gutter ball (entry 0.0 under every calibration). The remaining
0.3 board gap is within the noise of the hand-fitted references themselves.

### Separating fixable from not fixable

NCC after alignment:

- Same clip, frame 0 vs 1 s and 2 s (no re-prop): 0.990-0.998. The bowler
  walking and the ball rolling do not disturb it.
- Batch 1 cross-clip: 0.983-0.996.
- Batch 2 re-props and batch 1 to batch 2: 0.55-0.83. Every one of these
  registrations was badly wrong (corner errors of 20-700 px), and the
  estimated deck motion was often far smaller than the truth (11 px estimated
  for a 730 px move). So the size of the estimate can't be trusted on its own;
  the NCC gate is what catches these.

There's a clean gap between 0.983 and 0.83.

### Surprise: the phone moves during a throw

On 5115 the homography finds a 3.6 px drift between frame 0 and 2 s. NCC
before correction is 0.968 and after is 0.997, so this is real motion,
probably the prop settling. Registering the first frame only is fine for
bumps between throws, but a sagging mount also drifts within a throw.

### Estimators compared

- **Translational only:** exact for pure shifts but useless for roll and zoom
  (16-35 px errors).
- **Tiles** (translation per tile plus a robust similarity fit): good for
  shifts, and it beat homography on one batch-2 pair (NCC 0.952). But it was
  worse on the 1% zoom case (0.9 board off), and it gives integer-pixel
  shifts at 0.5 scale.
- **Homography:** the best overall. Use it.

## Thresholds I'd ship

Measure motion at the deck in boards, using the calibration's deck width in
px / 39 (about 2.3 px per board on batch 1).

- **NCC after alignment below 0.95:** the phone moved too much. Ask to
  recalibrate.
- **Deck motion above 8 boards:** ask to recalibrate, even if NCC passes.
  Corrections that large are untested.
- **Otherwise:** always apply the correction, even when it is tiny; a
  near-identity correction is harmless. If it moved the deck by 1 board or
  more, tell the user in the review step that the lane was re-aligned, with
  the overlay drawn through the corrected calibration.

## Not tested yet

- Pins down vs racked between the reference and the throw, and the sweep bar
  coming down. The pin deck sits inside the band. If this lowers NCC on a
  good alignment, mask the deck row or use the frame after the rack sets.
- Lighting or exposure changes between frames, and people moving on
  neighboring lanes. The band includes neighboring lanes.
- 60 fps clips and the 1080 x 1920 vs 4K sizes. Coordinates are scaled, so
  this should only change timing.
- Real accidental bumps. The alley checklist already has a deliberate-bump
  drill.

## App integration plan

1. **Save the reference.** At calibration confirm, store a downscaled
   grayscale reference band (top 50%, about 540x480) with the session
   calibration.
2. **Shared code.** A `DriftCheck` type in Analysis/ holds the registration,
   the NCC gate and the corner transform, ported from this file. Unit tests
   use synthetic shifts on a bundled frame.
3. **Run on every throw.** In ClipReviewView, before analysis, register the
   clip's first frame. It takes about 10 ms, so it can run on appear.
4. **Use the result.**
   - Pass: analyze with the corrected corners and draw the existing overlay
     through them. If the deck moved 1 board or more, show a one-line note.
   - Fail: show the existing recalibrate action as the primary button, with a
     plain message that the phone moved.
5. **Re-anchor.** After a successful correction, the throw's frame becomes the
   new reference, so slow sag doesn't build up past the gate.
6. **Later, for within-throw sag:** also register a frame near the end of the
   clip, and warn if it differs by more than 1 board.
