# Automatic lane calibration and handheld recording: research

Nov 18, 2026. Research only, nothing built. Question: can TrueLine (1) find
the lane on its own so the user only confirms, and (2) let the user record
handheld, mapping each ball position through that frame's own homography?

## Summary and recommendation

**What the market does.** No phone app that measures geometry in field
coordinates supports handheld recording. SwingVision, HomeCourt, Fulltrack AI,
LaneTrax and Striker all tell users to mount the phone and keep it still.
Auto calibration is common (SwingVision, HomeCourt, LaneTrax), but every
product keeps a manual fallback, and LaneTrax's reviews show its auto lane
detection is the most complained-about part of setup ("finicky", "doesn't try
to automatically re-detect the lane", lost the lane from table vibration).
Golf swing apps that work handheld (V1, 18Birdies) do so because they measure
body pose, not positions on a calibrated surface.

**Feasible for 1.2 (low risk, builds on what exists):**

1. **Within-throw drift correction ("forgiving tripod").** Run the existing
   `DriftCheck` registration (Vision homography on the top 50% band, NCC gate)
   on every few frames of a throw, not just the first. The Nov 1 prototype
   already measured about 1 px at the deck for bumps and found a real 3.6 px
   sag inside one throw (IMG_5115). This fixes LaneTrax's top complaint
   (a table or a sagging prop losing the lane) for propped phones, chairs,
   bags and wobbly tripods. Freeze the registration before the ball reaches
   the pins, because pin action and the sweep change the band.
2. **Confirm-only calibration for repeat sessions, plus snap refinement.**
   Keep the 6-tap fit as the source of truth. Add (a) arrow template matching
   in the rectified top-down view and (b) gutter/foul-line edge snapping, to
   polish a coarse homography. That is the "line-snap refine" stretch item in
   `calibration-v1.1-plan.md`, and it makes "reuse last calibration, confirm
   the overlay" good enough for most returning users.

**Research bets (do not promise for 1.2):**

3. **True handheld.** Physically possible for entry board, hard for arrows.
   Rotation is handled well by far-band registration, but hand translation
   is not: each 1 cm of sideways drift that the registration misses costs
   about 0.2 board at the arrows (the deck is fine, see the budget section).
   It needs a second, lane-plane anchor near the camera (foul line, gutters,
   arrows), and the bowler hides that region at the moment it matters. It
   needs a handheld-vs-tripod ground-truth session before any claim.
4. **Fully automatic lane finding with a small learned keypoint model.** This
   is the approach that works in tennis and soccer, but it needs roughly 1,000
   to 10,000 labelled frames from many centers. The hard part (seen in the
   Aug 15 sweep: 0/6, five locked onto neighbor lanes or reflections) is lane
   identity, not edge finding. A learned model proposing and a human
   confirming is the only shape worth building.

**Avoid:**

- **ARKit for capture.** It tops out at 60 fps on a binned 1920x1440 stream
  (4K is 30 fps only), gives no documented way to use the 2x crop the
  metrics depend on, its relative translation drift (about 2 cm per second in
  one study) is the same size as the error we are trying to remove, and
  plane detection cannot reach a lane 20 m away.
- **System video stabilization (standard, cinematic, cinematic extended).**
  It applies an undocumented per-frame warp (including rolling-shutter
  correction) and crops the field of view. That breaks the one-homography-
  per-frame model. Keep stabilization `.off`. I found no public AVFoundation
  "action mode" API; the nearest is `cinematicExtendedEnhanced`.
- **Gyro-only compensation.** It cannot see translation, and gyro bias
  integrated over a 3 to 5 s throw is the same order as the 0.02 degree
  rotation budget. Use the gyro only as a prior for image registration.
- **Feature matching on the lane surface itself** (ORB, AKAZE on the boards).
  The lane is glossy, low texture, has a pattern that repeats every board,
  and its reflections move with the camera rather than with the plane. All
  of these produce confident wrong matches. Register on the far band (deck,
  masking unit, kickbacks, ceiling) and on the lane's painted markings and
  edges, never on the wood grain.

---

## 1. Products

| Product | Sport | Calibration | Handheld? | What users say |
|---|---|---|---|---|
| SwingVision | Tennis, pickleball | Automatic court detection; setup screen confirms framing (9.5.7) | No. Fence mount preferred, tripod as fallback | 4.7 stars on App Store; reviews cite trouble lining up in bright sun, shadows, 85 to 90% shot accuracy by one user's estimate |
| HomeCourt | Basketball | Automatic court and hoop detection | No. Tripod or a stand, "remains in stable location while recording" | Not reviewed in depth here |
| Sportsbox AI | Golf | None (pose model, face-on video) | Tripod or a still hand; 2022 guidance says 4 ft and keep it still | n/a |
| V1 Golf, 18Birdies | Golf | None (pose and playback) | Yes, propped or handheld | n/a |
| Hudl Technique, Golf Fix | Golf | None found | Not verified | n/a |
| Fulltrack AI | Cricket | Semi-automatic: user aligns stumps in on-screen boxes, stumps are the calibration | No. Tripod 1.3 m+ about 4 m behind the stumps | Reviews: ball path not picked up even on a sturdy tripod; "inaccurate data is often due to setup issues" per their FAQ |
| Velocity (Athla) and other pitch-speed apps | Baseball | Fixed placement rules or manual frame picks | "Hands-free" placement 20 ft back and 20 ft aside | Claims of 0.3 to 1 mph vs radar, not independently tested |
| LaneTrax | Bowling | Automatic "Detect Lane" by default; manual 4-corner drag as fallback; lane must fill 25% of the screen, full rack up | No. "Mount your iPhone on a stable tripod", aligned with the right gutter for righties, high, behind the ball return | 4.8 stars, 701 ratings. Detection "finicky", "doesn't try to automatically re-detect the lane", lost the lane from table vibrations, "Manual or auto detect doesn't matter still a pain". Developer says v2 "automatically zooms into the lane and corrects small misalignments on its own" |
| Striker: Bowling Coach | Bowling | "Set four lane corners" | No. "Record from a tripod behind the lane" | Too few ratings to show |
| AI Bowling | Bowling | Manual corner marking per a review; later notes mention calibration-based neighbor-lane filtering | Not stated | 4.0 stars from 3 ratings |
| Track My Roll | Bowling | Listed "Auto lane detection" | Not stated | Gone: US App Store page now 404 |
| Specto (Kegel) | Bowling | Fixed ceiling cameras, installer calibrated | n/a | Benchmark only |
| Brunswick "Bowler Vision" (center system, older) | Bowling | Automatic: detects a tape mark at 45 ft and the flags at the start of the lane | Fixed camera | Shows that even fixed systems used dedicated targets to calibrate |

BowlerX, LaneSight and "Bowling Ball Tracker" did not turn up as App Store
products. No bowling app found allows handheld recording.

Pattern worth copying: every product that does auto calibration keeps a
manual path and keeps the phone still. SwingVision went further and is
moving to motorized and permanently installed cameras rather than handheld.
The competitive opening is not handheld; it is setup that survives bumps and
re-detects on its own, which is item 1 above.

Sources:
- LaneTrax setup docs: https://docs.lanetrax.app/getting-started.md
- LaneTrax lane selection: https://docs.lanetrax.app/ios/newsessions/lane-selection.md
- LaneTrax App Store reviews: https://apps.apple.com/us/app/lanetrax/id6475736816?see-all=reviews
- Striker: https://apps.apple.com/app/id6800074214
- AI Bowling: https://mwm.ai/apps/ai-bowling/6475312282
- Track My Roll (404): https://apps.apple.com/app/id1069783532
- Brunswick Bowler Vision case study: https://mitsi.com/case-studies/bowling-displays-and-tracking-with-mtsi/
- SwingVision mounting: https://www.tennis.com/news/articles/fair-play-swingvision-puts-its-electronic-line-calling-to-the-test-in-tournament-play
- SwingVision reviews: https://justuseapp.com/en/app/989461317/swingvision-a-i-tennis-app/reviews
- SwingVision setup redesign: https://www.tennisnerd.net/?p=27206
- SwingVision ITF PAT report (approval does not establish line-call accuracy): https://www.itftennis.com/media/15294/pat-25-037-approval-report-swingvision.pdf
- HomeCourt setup: https://www.homecourt.ai/in-app/gettingstarted and https://help.homecourt.ai/hc/en-us/articles/9344374524179-How-should-I-set-up-my-device
- Sportsbox: https://www.firstcallgolf.com/features/feature/2022-12-13/is-sportsbox-ai-leading-golfs-next-technological-revolution
- Golf apps handheld: https://fulcria-labs.github.io/blog/best-golf-swing-analyzer-apps-android and https://help.18birdies.com/article/756-instant-swing-playback
- Fulltrack AI: https://www.fulltrack.ai/faq and https://www.fulltrack.ai/
- Velocity (Athla): https://apps.apple.com/us/app/id1092992847

## 2. Automatic calibration techniques

### Learned keypoint and line heatmaps (what works in other sports)

- **TennisCourtDetector** (github.com/yastrebksv/TennisCourtDetector):
  TrackNet-style heatmap net, 640x360 input, 14 court keypoints plus a
  center point. 8,841 labelled 1280x720 frames from broadcast highlights.
  Median error 2.83 px raw; 1.83 px after a classical refinement (line
  intersections in a crop) plus fitting a homography to the court model and
  snapping occluded points. 96% of points within 7 px. Lesson: the
  classical refine and model fit after the net are worth as much as the net.
- **SoccerNet camera calibration.** 22,816 labelled images. The 2023 winner
  (Falaleev and Chen) used HRNetV2-w48 keypoints plus line detection plus
  extra line intersections, then OpenCV calibrateCamera. Code:
  github.com/NikolasEnt/soccernet-calibration-sportlight. Write-up:
  https://nikolasent.github.io/deeplearning/computervision/2023/06/20/SoccerNet-Camera-Calibration-2023.html
- **PnLCalib** (arXiv 2404.08401, github.com/mguti97/PnLCalib): HRNetV2
  keypoints (57) and line heatmaps (23), then a points-and-lines refinement.
  Homography IoU on WC14 97.0% part / 93.4% whole. Runtime 164 to 439 ms per
  frame on an RTX 2080 Ti plus a Xeon CPU. Not a phone model as published.
- **TVCalib** (WACV 2023, arXiv 2207.11709): no keypoints; segments the
  field markings and minimizes segment reprojection error over camera
  parameters. Lower accuracy than PnLCalib (JaC5 about 40 to 58) but the
  idea, fitting the known template to detected line pixels, is exactly the
  overlay-fit refinement TrueLine already has.
- **KpSFR, "Sports Field Registration via Keypoints-aware Label Condition"**
  (CVPRW 2022, https://ericsujw.github.io/KpSFR): dense grid of keypoints
  so that some are always visible; DLT plus RANSAC. Introduced TS-WorldCup,
  3,812 frames from 43 videos.

Data needs: the working systems use roughly 4,000 to 23,000 labelled frames.
A bowling lane is easier in one way (one fixed template, few camera
positions, all behind the approach) and harder in another (several identical
lanes side by side, which is a labelling of identity, not of geometry).
A reasonable first target is 1,000 to 3,000 frames from 20+ centers,
labelled for: foul line ends, the 7 arrow tips, the outer dots, headpin
spot, deck corners, and "is this the user's lane". TrueLine's own
human-confirmed calibrations are free labels, but the app collects no data,
so labels must come from Adam's clips, consenting testers, and public
video.

Phone feasibility: calibration runs once per session, so latency barely
matters; even 500 ms is fine. A MobileNet or small UNet heatmap model at
256 to 512 px input fits easily on the Neural Engine. Note the open ANE
zero-box issue from the ball detector before shipping a second model
(see memory: ball tracking debug). A tennis paper with a ResNet50 at
448x448 for 14 court points reports real time but no phone numbers
(arXiv 2511.04126).

### Classical line detection

Hough or LSD on the gutter edges, intersect them for the vanishing point,
find the foul line as the strong horizontal edge. This is TrueLine's
existing `LaneAutoDetector`; Aug 15 sweep 0/6, failures from neighbor lanes,
divider reflections, and gutter-like edges continuing below the foul line.
The tennis literature agrees: classical Hough plus homography (Farin et al.
2003) needs help on amateur footage (shadow removal, object detection,
arXiv 2404.06977). Classical is good for refinement once a coarse estimate
says which lane, and bad at choosing the lane.

### Arrow template matching

Best used after a coarse homography: rectify the lane to a top-down view,
then the 7 arrows sit at boards 5, 10, 15, 20, 25, 30, 35 in a known V and
have a known shape, so a single small template slid along a narrow band
finds them, and the V constraint rejects false hits. This gives lane-plane
anchors exactly where the arrow metric is measured, which is what the
handheld problem lacks. Arrow color and contrast vary by center (dark
triangles, colored, some faded), so match on edges and score by consistency
across all 7.

## 3. Handheld or moving-camera tracking

### Geometry first: what hand motion does

- **Rotation** (the dominant hand motion) moves every pixel by the same
  homography regardless of depth. Any static content, including the masking
  unit and ceiling, measures it correctly.
- **Translation** moves near things more than far things. A homography
  measured on the far band is right at the deck and wrong near the camera.
  At 2x (focal about 3,800 px, inferred from 4.6 px per board at the deck)
  with the deck about 22 m and the arrows about 9.5 m from the phone, 1 cm
  of sideways hand drift leaves about 2.3 px of error at the arrows, about
  0.2 board. The deck itself would be off by 1 cm (0.37 board) if nothing
  registered it, but far-band registration does.

### Per-frame homography from features (ORB, AKAZE, KLT plus RANSAC)

Standard and well understood, but the lane is a bad surface for it. Planar
tracking benchmarks: POT-210 (210 videos) scores success at under 5 px
corner error, and finds motion blur the hardest factor for every tracker
type. WOFT (WACV 2023) argues sparse keypoints fail on low-texture planes and
dense weighted optical flow halves the error of the best prior method on
POT-210. I found no published number for a glossy, repeating, reflective
surface like a lane; expect worse than POT-210. Mask out the lane surface
itself and the bowler's region; use the far band plus painted lane
markings and gutter edges.

- POT-210: https://alphaxiv.org/benchmarks/temple-university/pot-210
- WOFT: https://openaccess.thecvf.com/content/WACV2023/papers/Serych_Planar_Object_Tracking_via_Weighted_Optical_Flow_WACV_2023_paper.pdf
- PlanarTrack (1,000 sequences, blur subsets): https://www.alphaxiv.org/benchmarks/chinese-academy-of-sciences/planartrack

### Apple Vision registration

- `VNHomographicImageRegistrationRequest` (iOS 11+) returns a perspective
  warp aligning two images. Apple publishes no accuracy, speed or
  moving-object behavior. Docs:
  https://developer.apple.com/documentation/vision/vnhomographicimageregistrationrequest
- `VNTranslationalImageRegistrationRequest` returns only an x, y shift.
  Apple's own WWDC20 Action and Vision sample uses it as a "is the scene
  stable yet" gate before analyzing a board game field, and finds the board
  with a trained detector, which is the same propose-then-measure pattern.
  https://wwdcnotes.com/documentation/wwdc20-10099-explore-the-action-and-vision-app/
- TrueLine's own measurement (experiments/drift_check/README.md, Nov 1):
  homography on the top 50% band, half scale, about 10 ms on the Mac.
  Deck error after correction 0.03 to 0.4 px for 20 px shifts, 1 degree roll
  and 2% zoom; 1.6 px for a 10 px shift plus 2 degree roll. NCC 0.990 to
  0.998 with the bowler walking and the ball rolling, so moving foreground
  does not disturb it when it stays out of the band. Extrapolation to the
  foul line (outside the band) was off by up to 10 px. Translational only
  was compared there too; homography won.
- Unknowns to test on device: speed on iPhone at 60 fps (it only needs to
  run on a subset of frames, then interpolate, since analysis is after
  capture), and behavior under motion blur.

### ARKit world tracking

- Formats: default path bins the sensor to 1920x1440 and runs "at up to
  60 frames per second". 4K (3840x2160) is 30 fps only, iPhone 11 and up.
  Apple recommends HD at 60 fps for high-frame-rate apps. No 120 or 240 fps.
  (WWDC22 session 10126: https://developer.apple.com/videos/play/wwdc2022/10126/;
  `supportedVideoFormats`:
  https://developer.apple.com/documentation/arkit/arconfiguration/supportedvideoformats)
- No documented zoom. The 2x crop TrueLine relies on would have to be a
  digital crop of the 1920x1440 frame, about half the pixels per board of
  the AVFoundation 2x path. Exposure and white balance are adjustable through
  `configurableCaptureDeviceForPrimaryCamera`, with Apple's warning that
  strong changes degrade tracking.
- Pose accuracy: ARKit absolute trajectory error 16 to 43 mm on iPhone X
  (RD-VIO, arXiv 2310.15072); relative drift about 0.02 m per second on an
  iPhone 12 Pro Max (Sensors 2022, https://api.crossref.org/works/10.3390%2FS22249873);
  25 cm walk-away-and-return drift on iPhone 11 (arXiv 2109.14757). A 2026
  forum thread reports drift regressions on LiDAR iPhones in iOS 26.4+
  (https://developer.apple.com/forums/thread/827240). Centimeter-level
  translation error is the same size as the problem.
- Plane anchors and raycasts help near the user, not at 20 m. LiDAR range is
  about 5 m, and a visually estimated plane at a grazing angle 20 m out has
  no usable depth precision. ARKit cannot pin the lane; the lane markings
  must still do it.
- Verdict: ARKit's rotation is good but Core Motion gives the same rotation
  without giving up the AVFoundation capture path.

### Core Motion gyro as a rotation prior

Gyro plus frame timestamps is the classic route to stabilization and
rolling shutter correction (Karpenko, Jacobs, Baek, Levoy, Stanford CSTR
2011-03, ran on an iPhone 4: https://graphics.stanford.edu/papers/stabilization/).
They had to estimate gyro-to-camera delay, rolling shutter time and gyro
drift from a recording. Apple publishes no iPhone gyro noise or bias figure
(WWDC 2012 talk on Core Motion describes bias and its effect on attitude
error). Use it to predict each frame's rotation so registration starts close
and rejects wrong solutions; do not integrate it as the answer.

### Stabilization modes

`AVCaptureVideoStabilizationMode` cases: off, standard, cinematic,
cinematicExtended, cinematicExtendedEnhanced, previewOptimized, auto,
lowLatency ("reduced field of view", no added latency).
https://developer.apple.com/documentation/avfoundation/avcapturevideostabilizationmode
All of them warp frames by a transform the app is not given, and crop. A
calibrated homography from frame 0 does not carry to frame N through that
warp, and rolling shutter correction makes it non-homographic. TrueLine sets
no mode today, which leaves the default off; keep it that way. OIS is a
separate question: a forum thread asking whether `.off` also disables
lens-shift OIS got no answer (https://developer.apple.com/forums/thread/801283).
OIS shifts the image slightly per frame; per-frame registration absorbs it.

### Motion blur and rolling shutter

- Rolling shutter on the iPhone 15 Pro main camera measured 5.3 ms full
  frame (CineD, mode not stated:
  https://cined.com/iphone-15-pro-lab-test-rolling-shutter-dynamic-range-and-exposure-latitude/).
  Assuming handheld rotation of 1 to 3 degrees per second, the skew across a
  frame is 0.005 to 0.016 degrees, roughly 0.1 to 0.2 board at the deck and
  mostly absorbed by a per-frame homography. Small, but measure it.
- Motion blur matters more for registration than for the ball. Under
  alley lighting at 60 fps, exposure can approach 16 ms; 2 degrees per second
  of hand motion smears the background about 2 px at 2x. The ball already
  smears far more than that from its own speed, so the detector is not the
  weak link; the far-band registration is, and POT-210 confirms blur is the
  hardest condition for planar trackers.

## 4. Accuracy budget

Today with a fixed camera: entry board about 0.4 board, arrows about 0.15
board, deck 4.6 px per board at 2x 1080p.

To keep entry within about 0.5 board total, handheld registration may add
about 0.25 board, which is about 1.2 px at the deck per frame. In angle
that is about 0.018 degrees.

- Far-band Vision homography already measured 0.03 to 0.4 px at the deck
  for single-motion bumps and up to 1.6 px for combined shift and roll. So
  entry board handheld looks reachable, if blur does not degrade it.
- Arrows are the hard part. The arrows need 0.15 board, about 1.6 px at an
  assumed 10.8 px per board. Far-band registration alone leaves about
  2.3 px per cm of hand translation, so it fails above about half a
  centimeter of drift. It needs lane-plane anchors near the arrows (arrow
  template match, gutter edges, foul line), which the bowler occludes during
  the approach and release.
- Gyro rotation to 0.018 degrees over a 4 s throw needs residual bias below
  about 0.005 degrees per second. Not something to assume.
- Published planar-tracking numbers (POT-210, PlanarTrack) use a 5 px success
  threshold, three to four times our budget, on textured targets. Nothing
  published covers a low-texture, glossy, repeating surface at this
  precision.

Realistic expectation: handheld entry board within about 0.5 to 1 board,
handheld arrows within about 0.3 to 0.6 board, unless near-lane anchoring
works well. A propped or tripod phone with per-frame drift correction keeps
today's accuracy and removes the failure mode users actually hit.

## 5. Suggested next experiments (cheap, in order)

1. Run `DriftCheck` registration on every 5th frame of the Aug 17 clips,
   plot deck motion over time, confirm NCC stays above 0.95 through the
   bowler's approach, and check what pin action does to the band.
2. Record 3 handheld and 3 tripod throws on the same lane at the next alley
   visit (P9 in `detector-retraining-plan.md`), with Core Motion logged.
   Measure hand rotation rate, translation (from near-lane markings) and
   blur directly instead of assuming them.
3. Prototype arrow template matching in the rectified view on existing
   clips; measure arrow-board repeatability against the 6-tap fit.
4. Only then decide whether a learned lane keypoint model is worth labelling
   1,000+ frames for.
