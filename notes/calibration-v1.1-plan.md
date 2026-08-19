# Calibration v1.1 plan

Decided with Adam, Aug 19 2026. v1.1's core is calibration accuracy: the
error budget (notes/model-eval.md) puts detection at ~half a board and the
rest on far-end corner precision (~2.3 px/board at the deck in 1x footage).
The design constraint Adam set: ease of use first. No camera line-up
rituals, no long tap sequences. Same-or-fewer taps than today, every
target obvious.

## The three sub-problems

1. **Placing points precisely is physically hard.** Two of today's four
   taps are far deck corners: tiny, low-contrast, occluded, next to
   neighbors' decks (the wrong-deck trap).
2. **Error is invisible.** Nothing tells the user their calibration is
   off until a throw's line looks wrong.
3. **It doesn't stay right.** A bumped phone silently reuses stale
   corners (the drift problem from the Aug 17-18 alley session).

## Design direction

### Easy landmarks + live overlay, one interaction metaphor

- Initial taps target **recognizable objects**, not abstract corners:
  foul line corners (big, near), outer arrows, headpin base (board 20,
  60 ft — unmistakable, unlike deck corners). Roughly 4-5 taps, all easy.
- More than 4 points -> **least-squares homography**, so no single sloppy
  tap dominates.
- Then a **live reprojected overlay**: the lane's known geometry (arrows,
  board lines, deck outline) rendered through the homography onto the
  frame. Misalignment is instantly visible. Fine-tuning = drag the
  overlay's features onto the real ones ("make the drawing match the
  lane"); each drag re-solves the homography. Loupe magnifier during
  drags.
- The overlay doubles as the **wrong-deck guard** (a neighbor's deck
  skews the whole drawing) and as the **drift check**: on each throw's
  confirm step, draw the same overlay on a fresh frame from that throw.
  Shared rendering code.
- **Quality score**: compute px-per-board at the deck; warn "far end too
  small — use 2x" when precision is physically unattainable.
- **Line-snap refine** (stretch): local edge detection snaps a dragged
  corner/edge to the detected lane edge. Semi-auto only — the human does
  the coarse work (where full auto-detect failed 0/6), CV does the last
  few px.

### Geometry caveat to test, not argue

Easy near/mid landmarks mean the deck — where entry board is measured —
is extrapolated. Whether "5 easy points" beats "4 points incl. 2 sloppy
deck corners" is empirical. Harness experiment decides it (below).
Likely answer is a hybrid: easy landmarks seed the homography, overlay
drag refines the deck.

### Camera distortion: measure, then maybe one radial term

Lane edges are long straight lines through the frame — the plumb-line
method measures lens bend directly from the alley clips, zero user
effort. If max deviation is a couple of px: note it, move on (2x is a
center crop of the main sensor; distortion should be mild). If material:
fit a single k1 radial term from the lane edges themselves and bake
undistortion into the pipeline. No checkerboards, no user steps, ever.

## Build order

1. **Harness experiments (Python, before any iOS work):**
   a. Landmark-set comparison — Monte-Carlo realistic tap noise on the 8
      alley clips; compare entry-board error for: current 4 corners,
      easy-landmarks-only, easy landmarks + overlay-refined deck.
   b. Plumb-line distortion measurement on the same clips; decide
      whether k1 is warranted at 1x and 2x.
   c. Line-snap feasibility: local edge detection around hand-placed
      corners; success rate + px improvement.
2. **iOS calibration flow rebuild:** easy-landmark taps -> live overlay
   -> drag-to-match refine + loupe + quality warnings. Informed by 1a.
3. **Drift check on throw confirm** (reuses overlay renderer).
4. **Line-snap assist** if 1c says it's reliable.
5. **Ground-truth alley session** — marked target board, known speeds,
   app-vs-tape. Acceptance test for the whole package and the gate for
   any accuracy claims in marketing.

Constraint: no new binary submitted while v1.0 sits in review; all of
this lives on the v1.1 branch until approval.

## Deliberately not doing

- Full auto-detect as primary (0/6 on real clips; stays as a seed at most)
- Checkerboard / per-device intrinsics calibration
- Drag-4-lines full redesign (hold unless overlay-drag still feels clumsy)
- Framing overlays on the record screen (minimal-capture-guidance rule)
