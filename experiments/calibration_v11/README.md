# calibration_v11 — reference calibrations + accuracy experiments

Ground-truth-quality lane calibrations for the 8 alley clips
(data/test_videos/alley-2026-08-17/), built from physical lane landmarks
instead of hand-guessed corners. These references feed the v1.1
calibration experiments (notes/calibration-v1.1-plan.md): the tap-noise
Monte Carlo, distortion measurement, and line-snap feasibility.

## Layout

- `landmarks/<clip>.json` — hand/CV-measured image coordinates of physical
  landmarks (guide dots, arrows, headpin, pin columns, foul-line sampling
  corridor). The curated per-clip input.
- `references/<clip>_ref.json` — fitted reference: image->lane homography,
  derived 4-corner points (app format), fit metadata. Generated.
- `overlays/<clip>_overlay.png` — lane geometry drawn on a frame for
  eyeball review (Adam approves these before the references are used).
- `frames/` — extracted frames + zoom scratch (gitignored).
- `detections/` — cached YOLO ball tracks per clip (gitignored).

## Scripts

- `build_reference.py landmarks/<clip>.json` — joint least-squares fit of
  homography + landmark distances; writes reference + overlay.
- `entry_board.py <video> <ref> [legacy_cal]` — detect ball, compute entry
  board at 60 ft under reference vs legacy calibration.
- `zoomgrid.py` — gridded zoom crops for hand-reading pixel coordinates.
- `plumbline.py` — straight-line-based lens distortion probe.
- `fit_reference.py` — earlier corner-weighted fit, superseded by
  build_reference.py; kept for the record.

## Conventions

- Lane coords: x in [0,1], 0 = RIGHT gutter edge, 1 = LEFT (39 boards);
  y in feet from the foul line (60 = headpin row). Board k center is at
  x=(k-0.5)/39, board 1 at the right gutter (right-hander convention,
  matches src/calibration.py).
- Guide dots sit on boards 3,5,8,11,14 / 26,29,32,35,37; arrows on
  5,10,15,20,25,30,35 (regulation). Dot-row distance and the arrow-V
  depths are fitted per clip (they are house-specific).
- Pin columns (7 visible from behind): boards 37, 31.28, 25.64, 20,
  14.36, 8.72, 3.08.
- Distortion k is pinned ~0: these landmarks cannot constrain it, and
  k=0 fits to ~0.5 board worst-case. See notes below before "fixing" it.

## Findings so far (IMG_5108, Aug 21)

1. Visible gutter/deck edges are treacherous: the specular gutter+capping
   band shows several plausible "edges"; the wood|gutter boundary at the
   dot row sat 66 px inside the edge a careful human picked. The bright
   deck region blends with flat gutters. Physical markings (dots, arrows,
   pins) are the only trustworthy calibration features. This is the core
   argument for landmark-first calibration UX in the app.
2. The dot row fits a 1D projective at 0.32 px rms — the markings are
   regulation-accurate and CV-detectable (blackhat blob detection).
3. Reference validation: the confirmed-strike clip IMG_5108 reads entry
   board 17.56 (textbook pocket = 17.5) with the ball tracked 2->69 ft.
4. The legacy hand calibration (data/calibration.json) reads 17.96 on the
   same throw — right answer near the pocket, but its gutter lines are
   ~5+ boards off at the edges (errors cancel mid-lane). Explains why the
   Aug 18 "verification" passed while edge geometry was wrong.

## Full-sweep validation (all 8 clips, Aug 25)

Ball detected per frame (models/ball.pt, conf 0.30), entry board at 60 ft
via each clip's own reference. Adam's stated batch-1 outcomes: 1 strike,
2 misses, 1 gutter.

| Clip | Coverage | Entry/read | Interpretation |
|------|----------|------------|----------------|
| 5105 | full lane, 1-68 ft | entry 11.9 | miss, light/right ✓ |
| 5106 | dies 45 ft | board −3.4 to −4.5 at 39-45 ft | GUTTER ball, mapped outside lane ✓ |
| 5107 | full lane, 1-68 ft | entry 11.7 | miss, light/right ✓ |
| 5108 | full lane, 2-69 ft | entry 17.56 | STRIKE, textbook pocket ✓ |
| 5112 | dies 20 ft | ~board 9 mid-lane | detection gap (tilted view) |
| 5113 | only 45-59 ft | ~15.3 at 58.8 ft | detection gap near lane |
| 5114 | only 49-57 ft | ~13.1 at 57 ft | detection gap |
| 5115 | dies 36 ft | ~9.9 at 36 ft | detection gap |

Every batch-1 outcome is reproduced by the references, including the
gutter ball reading negative boards. Batch-2 boards are physically
sensible where detections exist; coverage, not calibration, is batch-2's
limiter — the placement-sensitivity retraining item in
notes/calibration-v1.1-plan.md.

Batch-2 placement note: the phone was re-propped between EVERY batch-2
clip (5112/5113≈5114/5115 all differ; 5114 is rolled). Real users will do
this too — supports per-throw drift checking and cheap recalibration.
