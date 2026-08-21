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
