# Rev rate research (Nov 1, 2026)

Research pass before building rev rate into the app. The question is which
technique can give a trustworthy RPM from one iPhone behind the approach.
It builds on the prototype in `experiments/rev_rate/` (ball-patch brightness,
then FFT, with a split-half gate) and on the plan in `alley-visit-checklist.md`
and `next-steps-2026-11.md` (that file is on the `stage` branch only).

Short version:

- Nobody publishes accuracy numbers for rev rate. That includes Specto, the
  apps and the in-ball sensors.
- No phone app found measures rev rate both automatically and in a way it can
  defend. The others either have the user count frames by hand, or show a
  number without saying how it is made.
- Rev rate is not constant down the lane. A ball can be spinning 30 to 80
  percent faster at the back end than at release. Our current 2.2 s FFT window
  covers most of the lane, so it is biased high compared with the "release" rev
  rate bowlers mean. Measure in the first ~20 ft.
- Tape placed *at* the PAP is nearly useless for a brightness signal, because
  the PAP is the spin pole. The checklist currently says "near your PAP". Use a
  USBC-style strip that runs from the PAP out past the finger holes instead.
- The iPhone 16 Pro can record 1080p at 240 fps and 4K at 120 fps, and the app
  can lock a short shutter. A short high-fps burst over the first second of the
  throw is worth more than any algorithm change.

## 1. How existing products measure rev rate

### Lane systems

**Specto (Kegel).** Specto's own FAQ says it uses "a lidar sensor that reads up
to 6 lanes" and an infrared sensor, and that it "gathers about 120 readings per
lane per shot". Its glossary defines REVS/RPM as "Calculated revolutions of the
ball". The Specto tutorial, as quoted on Maverick, calls RPM "a calculated
number ... based on a number of factors". A lidar range reading cannot see the
ball spin, so Specto's RPM must be inferred from the path and speed profile. It
is not observed directly. Forum users say it is "calculated with a big error",
and that Specto "usually [uses] a formula and doesn't actually read the
revolution on the ball". No accuracy figure is published.
([Specto FAQ](https://www.spectobowling.com/frequently-asked-questions),
[Specto terms](https://www.spectobowling.com/specto-terms),
[Maverick thread on Specto lidar](https://forum.maverickbowling.com/viewtopic.php?t=14698),
[BowlingBoards thread](http://www.bowlingboards.com/archive/index.php/t-22363.html))

**CATS / Super CATS (USBC, Kegel).** This system uses 23 sensors in the lane
for position and speed. The Kegel patent US6110052 handles spin separately:

- A rear video camera at 30 fps behind the foul line.
- A tape "indicator" about a quarter of the ball's circumference long, running
  out from the spin axis.
- A person counts the indicator's rotation over 10 frames. Rotations × 180 = RPM,
  or "clock hours" × 15 = RPM.
- Spin is assumed constant over that 1/3 s.

([patent](https://patents.google.com/patent/US6110052),
[USBC motion study note](https://images.bowl.com/bowl/media/legacy/internap/bowl/equipandspecs/pdfs/articles/ResearchcompleteonUSBCBowlingBallMotionStudy.doc.pdf))

### Phone apps

| App | How rev rate is produced | Evidence |
|---|---|---|
| LaneTrax ($9.99/mo, $89.99/yr, ~669 ratings) | Not disclosed. Docs: "calculated by LOOKING at your ball". Version 1.0.6 (Sep 2025) notes say "improved accuracy for rev rate". | [App Store](https://apps.apple.com/app/id6475736816), [docs](https://docs.lanetrax.app/ios/newsessions/classic-mode), [site](https://www.lanetrax.app/) |
| BowlSense | Speed Check at 120/240 fps, "frame-by-frame analysis". The user follows a logo, tape or bright spot by hand. No accuracy figure is given. Its sensor analysis is labelled "experimental". | [App Store](https://apps.apple.com/us/app/bowlsense/id6760173811), [speed page](https://www.bowlsense.io/speed) |
| Tenpin Toolkit | Manual video tool. Says to capture at 120 or 240 fps and at least 3 consecutive revolutions. | [App Store](https://apps.apple.com/app/id1390556454) |
| Strike Zone Bowling Coach | The user counts tape revolutions on a recorded video. | [App Store](https://apps.apple.com/us/app/-/id6757426359) |
| Strikee | Video tracker lists laydown, arrows, breakpoint and speed. No rev rate. | [site](https://strikee.app/) |
| "Striker: Bowling Coach" | Could not find it on the App Store or the web under that name. Unverified. | |

**Correction to our competitor notes.** LaneTrax does ship rev rate. It is a
listed metric and has had accuracy updates. I could not find the "work in
progress" wording our November notes attribute to its developer. The verifiable
complaint is a July review: "the numbers don't always align with the video
replay". That review is about its stats in general, not RPM specifically. I
found no Reddit or forum discussion of LaneTrax RPM accuracy.

### Sensors

| Product | What it is | Accuracy claim |
|---|---|---|
| Storm / F5 sensor | In-ball, needs a drilled hole. Rev rate, axis tilt, axis rotation, track flare, rev-to-speed ratio. $199 kit plus $99/yr membership. | None published ([Storm](https://www.stormbowling.com/f5-bowling-sensor), [F5 shop](https://www.f5bowling.com/shop/f5-bowling-sensor)) |
| Witsee | Removable in-ball sensor | Only Trustpilot reviews ("very accurate on rpm") ([article](https://bowlinglife.eu/lithuanian-company-witsee-bowling-sensor)) |
| BowlSense Pro | Clip-on puck plus Apple Watch, $199.99 | "Experimental" ([shop](https://www.bowlsense.io/shop)) |
| SmartDot / RevMetrix | Academic. A light sensor in a finger hole (2002), then an accelerometer module | The thesis reports a ~5% unexplained gap between its two RPM estimates and ~10 RPM resolution steps ([Hake thesis](https://ycpcs.github.io/cs400-fall2023/projects/RevMetrix-Project/Hake-MEngESci-Masters-Thesis.pdf)) |
| Lanecaddie (Apple Watch) | Wrist IMU | Rev rate "coming in a later update" ([site](https://lanecaddie-website.pages.dev/)) |

A wrist sensor cannot measure ball spin after release. At most it can estimate
release rotation from hand motion. I found nothing for "Bowler's Mark" or
"Bowler's Ally". Our November note puts sensors at about $319 and says none are
USBC-approved. I could not confirm either point; the USBC approved-devices page
returned 404.

### Takeaways

- No product publishes a rev rate error bar.
- The products that are honest about method all reduce to one of two things:
  - a human counting a marker in high-fps video, or
  - a sensor inside the ball.
- Specto, the brand bowlers trust, infers RPM rather than observing it.
- The open slot for TrueLine is an *automatic* rev rate with a *published,
  measured* accuracy, which none of the products above has. Rev rate as such is
  not a gap: LaneTrax already has it.

## 2. Manual and coaching methods

**USBC method.** ([bowl.com](https://bowl.com/what-s-your-rev-rate))

1. Find the PAP.
2. Put tape "from the axis to just above the finger holes".
3. Film the release and step from the first frame after the fingers leave.
4. Count clock hours covered in 10 frames, then hours × 15 = RPM at 30 fps.
   Scale by fps/30 for other frame rates.

USBC says the truest measurement is "immediately following the release". It
also warns that counting rotations while the ball travels measures "revolutions
per shot and not revolutions per minute".

**Revs-to-the-pins formula.** RPM = revs counted × 60 / travel time.
Maverick users point out that rev rate keeps rising until the roll phase, so
this gives a whole-lane average, not the release rate: "You can not calculate
your release RPM using the amount of revs on the full lane." The same thread
gives practical precision notes:

- Timing three revolutions at high fps is accurate to about 0.02 s.
- Whole-frame counting at 60 fps quantizes coarsely: 11 frames per rev is
  327 RPM and 12 frames is 300 RPM.
- One video measured four ways gave 420 to 450 RPM.

([Maverick "finding rev rate"](https://forum.maverickbowling.com/viewtopic.php?t=12829))

**How accurate is accurate enough.** No coach or governing body states a
tolerance. What we can infer:

- Style buckets are about 100 RPM wide: stroker roughly 200 to 300, tweener 300
  to 400, cranker 400+ ([Wikipedia: Bowling form](https://en.wikipedia.org/wiki/Bowling_form),
  [bowling.com](https://www.bowling.com/knowledge-hub/bowling-balls/bowler-types/all)).
  Ball matchup advice works at that coarse level.
- So ±25 RPM per throw is enough to classify a bowler and pick equipment.
- To track a bowler trying to add revs over weeks, the session average needs to
  be good to about ±10 RPM (~3%).
- The USBC/patent clock-hour method itself has about ±1 hour per 10 frames,
  which is ±15 RPM at 30 fps. Hand counting at 30 fps is no better than ±15.

Target: per throw within ±25 RPM, session median within ±10 RPM of 240 fps hand
counts.

## 3. Computer vision techniques from other sports

Our case is unusual:

- The ball is large and slow-spinning: 2.5 to 8 rev/s.
- It travels almost straight away from the camera, so the radius shrinks from
  ~100 px to ~15 px.
- Most sports spin work instead targets small, fast balls (baseball 30 to
  45 rev/s, table tennis up to 175 rev/s) filmed side-on at 300 to 2000 fps.

Our low spin rate is the advantage: 30 fps is already above Nyquist (2 × 8 rev/s
= 16 fps). Blur and the shrinking radius are the problems.

### Brightness or appearance periodicity (our approach)

Any textured ball surface looks the same once per revolution, as long as the
axis is stable. So a scalar such as mean brightness, or better a whole crop
descriptor, is periodic at the rev rate.

- Patch means survive motion blur, because blur averages pixels and averaging
  is what we do anyway.
- Cost is trivial on iPhone: a few hundred pixels per frame.
- The closest published idea is generic repetition counting from video
  self-similarity, e.g. RepNet (Dwibedi et al., CVPR 2020,
  [arXiv 2006.15418](https://arxiv.org/abs/2006.15418)). No sports spin paper
  does this for balls, so it is ours to validate.

Weaknesses:

- Harmonics. A pattern with two-fold symmetry, or two graphics, makes the 2×
  peak dominant.
- Axis drift and flare blur the periodicity.
- A marker that stays in view the whole revolution changes the mean very
  little (see section 4).

**Cheap upgrade.** Instead of one mean, compute a small normalized descriptor
per frame: the ball crop resized to 16×16, or 4 to 8 sector means. Then find the
period from the frame-to-frame similarity matrix. This catches a marker
*rotating within* the visible face even when the mean stays flat. It is still
cheap enough to run on every frame.

### Marker or logo tracking

This is the standard method:

- Rapsodo's golf spin needs special printed balls ("Callaway RPT").
  ([MyGolfSpy](https://mygolfspy.com/news-opinion/rapsodo-mlm2pro-takes-spin-measurement-to-pro-level/))
- Robot table tennis tracks the logo at 380 fps.
  ([Spin Detection in Robotic Table Tennis](https://cs.paperswithcode.com/paper/spin-detection-in-robotic-table-tennis))
- SpinDOE prints a dot pattern on the ball to get <1% spin error at 350 fps.
  The authors made it specifically because the logo "may not always be visible".
  ([arXiv 2303.03879](https://arxiv.org/pdf/2303.03879.pdf))
- A 2026 smartphone baseball method detects the ball with YOLOv8, then
  classifies the seam orientation into 4 bins with a CNN, unwraps the phase
  and fits a line. It gets 5.7% mean error with a 90% success rate on 15
  videos. ([Yamamoto & Matsumae, IJNC 16(2)](https://www.jstage.jst.go.jp/article/ijnc/16/2/16_166/_article/-char/en))
  This is the most transferable published pipeline: same detector family,
  coarse orientation classes and phase regression.

For bowling, the clock-hand method is marker tracking done by eye. Automating
it means finding the tape end or the finger holes and measuring their angle
around the ball center (or around the PAP) in each frame. Requirements:

- Ball radius above ~30 to 40 px, so a hole (about 1/8 of the diameter) is at
  least ~8 px.
- Rotation per frame well under 180°. At 30 fps and 480 RPM it is 96° per frame,
  workable but ambiguous with three similar holes. At 120 fps it is 24°, easy.
- Short exposure.

Cost: one extra small detector or a blob finder on the crop, so moderate.

### Optical flow on the ball surface

Event-camera work exists because "traditional low frame rate cameras are
inadequate for observing the logo and estimating spin because of motion blur"
([Gossard et al., CVPRW 2024](https://arxiv.org/abs/2404.09870v1)).

- Flow needs texture that persists between frames. That is plausible only in
  the first ~10 ft at 120 to 240 fps with a short shutter.
- At 30/60 fps with an auto shutter, surface texture is smeared. At 300 RPM a
  point 60° from the pole moves ~3 m/s, about 0.45 ball radii in a 1/60 s
  exposure.
- Cost is medium; Vision has `VNGenerateOpticalFlowRequest`.

Not recommended as primary.

### Image registration and template matching of the rotated ball

Tamaki et al. register a 3D sphere model between frames with Gauss-Newton
([Measuring ball spin by image registration, FCV 2004](https://ir.lib.hiroshima-u.ac.jp/00020427)).
Their slides admit "not yet quantitative evaluation". This needs a known focal
length and a good sphere fit. Boracchi, Caglioti and Giusti recover spin from
the blur of a *single* frame, but they need a textured ball and a calibrated
camera ([2009](https://boracchi.faculty.polimi.it/docs/2009_09_09_InstantaneousBall3DMotion_Boracchi.pdf)).

These are elegant but fragile at 15 to 40 px radius. They could be research
follow-ups for the near field, not a v1 path.

### 3D rotation from feature tracks

This recovers full spin axis plus rate. Statcast does it at 300 fps with
multiple cameras ([SI on Statcast](https://www.si.com/mlb/2023/11/15/how-it-works-mlb-pitch-tracking-baseball-statcast)).
From one phone, with a ball sized 15 to 40 px and blur, there are not enough
features. Axis tilt and rotation would be a great feature later, but they need
the tape or holes tracked in the near field at high fps.

### Deep-learning spin regression

The only monocular broadcast table tennis work trains on synthetic data and
reports spin *class* accuracy (92%), not rate
([arXiv 2504.19863](https://www.arxiv.org/pdf/2504.19863)). We have no labelled
corpus. This only becomes possible after many 240 fps-labelled throws exist.
Not for v1.

### Trajectory physics (hook and speed loss)

Tennis research found a ball-trajectory model estimated spin better than
Hawk-Eye's own spin output: bias 2.9 ± 223 vs −100 ± 542 rpm
([J Sports Sci 2020](https://lida.sport-iat.de/twm/Record/4059923?lng=en)).
Specto's "calculated" RPM is presumably this kind of method.

For bowling, friction changes the ball's angular velocity by exactly
(R/k²) × the change in velocity, where k is the ball's radius of gyration. If
the ball reaches roll before the pins, the release spin can be solved from:

- the launch velocity vector,
- the roll-out velocity vector,
- the ball's RG.

Physics source: [Frohlich, What makes bowling balls hook?](https://www.researchgate.net/publication/243492690_What_makes_bowling_balls_hook)

Limits:

- It is blind to the axis tilt component.
- It needs the ball to actually reach roll.
- It is the difference of two large numbers. In my estimate below, a 0.1 m/s
  speed error moves RPM by about 30.

Useful as a sanity bound, such as "this throw cannot be 150 RPM", not as the
measurement.

## 4. Bowling-specific physics gotchas

**Rev rate rises down the lane.** Friction converts speed into spin until the
ball rolls. At roll the spin is fixed by speed alone: v/(2πR) is about 550 RPM
at 14 mph, whatever the release rate was. Sources say rev rate climbs until the
roll phase:

- [Storm, How a bowling ball hooks](https://www.stormbowling.com/page-building-4)
- [Hake thesis §1](https://ycpcs.github.io/cs400-fall2023/projects/RevMetrix-Project/Hake-MEngESci-Masters-Thesis.pdf)

I ran a toy rigid-sphere skid model to put numbers on it (a throwaway
script outside the repo, about 30 lines, under a second of CPU). Assumptions:
RG 2.55 in, μ 0.04 in the first 40 ft and 0.20 after. The friction values are
illustrative, so read these as ballpark figures.

| Release | RPM at 10 / 20 / 30 / 40 ft | Whole-lane revs × 60 / time |
|---|---|---|
| 17 mph, 300 RPM, 45° rot | 316 / 336 / 360 / 387 | 403 |
| 15 mph, 250 RPM, 30° rot | 281 / 317 / 356 / 398 | 380 |
| 18 mph, 400 RPM, 60° rot | 400 / 403 / 410 / 421 | 448 |
| 17 mph, 300 RPM, 85° rot | 289 / 284 / 284 / 290 | 334 |

What this means for us:

- The first ~20 ft (first ~0.8 s) is within roughly 10% of release.
- The whole-lane average reads 10 to 50% high.
- Our prototype's 2.2 s window is mostly whole-lane.

**Re-check of existing signals, by window.** Read-only run of `estimate_rpm.py`
on the cached `signals/`. A `*` means the confidence gate passed.

| Clip | 2.2 s | first 1.2 s | first 0.9 s | 1.0 to 2.2 s |
|---|---|---|---|---|
| 5105 | 346 | 328 | 329 | **109*** |
| 5106 | 369 | 353* | 350* | 265 |
| 5107 | 385 | 386* | 382* | 143 |
| 5108 | 344* | 350 | 346 | 356* |

What I see:

- The early window carries the signal and agrees with the full window.
- The late lane is noise. The ball is 17 to 20 px there and the late signal
  repeats poorly.
- On 5105 the gate passed a **confident 109 RPM**, which is physically
  implausible. That is a real false positive on real data, and it argues for
  restricting analysis to the early lane and adding physical priors.
- The extractor's radius model puts the ball at 27 to 28 px at first detection,
  not ~100 px. Either the tracks start well past the foul line or `rk` is off.
  Worth checking before the alley data comes in.

**Axis rotation decides what the camera sees.** From directly behind:

- With 0° axis rotation (end over end), the spin axis is perpendicular to the
  view. Every surface point sweeps over the visible face and off it once per
  revolution, which gives strong flashes.
- As axis rotation approaches 90° (spinners), one axis pole points at the
  camera. Points within ~(90° − rotation) of that pole never leave the visible
  face. They circle like a clock hand, and mean brightness hardly changes.

The Kegel patent places its spin camera at the left rear for right-handers for
exactly this reason: so the axis and tape are visible.

So:

- Tape *at* the PAP is the worst choice for a brightness flash. It barely moves.
- A radial strip from the PAP outward, as USBC does it, is the best choice. The
  outer end sweeps a big circle and the strip's angle reads like a clock hand.
- The finger holes sit in a useful band. The USBC tape goes "from the axis to
  just above the finger holes", which puts the grip roughly a quarter
  circumference from the pole. That is a large circle, mostly in view.

**Axis tilt** adds a vertical component and makes the track ring smaller. USBC
measures tilt from the first flare ring
([USBC ball motion form](https://images.bowl.com/bowl/media/legacy/internap/bowl/equipandspecs/pdfs/BallMotionAnalysisFormInstructions.pdf)).
It changes which band of the ball is visible. It does not change the
once-per-revolution periodicity.

**Track flare and axis migration.** The axis migrates through the oil
transition, and the PAP moves between breakpoint and pins (USBC form above).
Each revolution then traces a slightly different path, so periodicity degrades
mid to late lane. This is another reason to measure early. Flare peaks with
pin-to-PAP distance around 3 to 4 in
([Storm, PSA/PAP](https://www.stormbowling.com/read/better-bowling-psa-pap-tips),
[bowlingball.com PAP](https://www.bowlingball.com/BowlVersity/the-importance-of-the-positive-axis-point)).

**Two flashes per revolution.** Logos and graphics are often printed on two
opposite faces, and there are pin and CG marks. Two similar bright features
about 180° apart give a dominant 2× peak. A dark grip cluster is one feature per
revolution and is the most reliable natural marker. It may be what our untaped
clips are actually locking onto, rather than the logo.

The current harmonic score, mag(f) + 0.5 × mag(2f), helps when the fundamental
is visible. It cannot recover a fundamental that is missing. Add a
**sub-harmonic test**: fold the signal at 2T and check whether alternate cycles
differ consistently. If they do, the true period is 2T.

**Lighting.** Alley LEDs and fluorescents flicker at 100/120 Hz. At 240 fps
with a short shutter, flicker shows up as frame-to-frame brightness changes.
The RevMetrix light sensor had to average away 120 Hz ripple. Normalizing by
the background annulus already removes most of it. Lock exposure and white
balance during capture so auto-exposure steps do not inject false edges.

**Which part of the lane is cleanest?** From the foul line to ~15 to 20 ft:

- the ball is largest (most pixels per feature),
- rev rate is closest to release (what bowlers and USBC mean),
- oil keeps friction low, so the rate is roughly constant,
- the axis has not migrated yet.

The first ~2 to 4 ft can be occluded by the bowler's body and hand. Start once
the track has cleared the slide foot.

## 5. Recommendations

### Ranked techniques

1. **Early-lane appearance periodicity at higher fps (evolve the prototype).**
   - Restrict to roughly 0.1 to 0.9 s after release, about 3 to 20 ft.
   - Capture that part of the throw at 120 fps (4K) or 240 fps (1080p). The
     iPhone 16 Pro supports both
     ([Apple specs](https://apple.com/sa/iphone-16-pro/specs),
     [MacRumors](https://www.macrumors.com/how-to/iphone-16-pro-shoot-4k-video-120-fps-slow-mo/)).
   - Lock a short shutter with `setExposureModeCustom(duration:iso:)`
     ([Apple docs](https://developer.apple.com/tutorials/data/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:).md)),
     aiming for ≤1/500 s if the alley light allows.
   - Replace the scalar mean with a small crop descriptor plus a self-similarity
     period, and keep the split-half gate.

   Why it ranks first:

   - It survives blur.
   - It works with tape, holes or graphics.
   - It is the cheapest thing on device.
   - It already gives consistent numbers on 30 fps footage.

   The tracker does not need to run at 240 fps. Run the detector at 30/60 on a
   decimated stream, interpolate the ball center, and sample crops from the
   full-rate frames for just that one second.

2. **Marker angle tracking (automated clock-hand method) in the same early
   window.**
   - Track the tape strip's outer end, or the finger hole cluster, as an angle
     around the ball center.
   - Unwrap the phase and fit a line, as in Yamamoto & Matsumae.

   Why it ranks second:

   - It gives per-revolution phase, so harmonic ambiguity disappears.
   - It is the same thing a human does to make ground truth.
   - It opens a path to axis rotation later.

   It needs ~40 px radius and 120+ fps, so it is limited to the first ~10 to
   15 ft. Use it as the disambiguator and confirmer for #1, and as the primary
   method in "tape mode".

3. **Trajectory physics bound.** From our own launch velocity, roll-out (if
   detected) and a default RG of 2.5 in, compute a plausible RPM range. Use it
   only to refuse answers outside that range, such as 5105's 109.

4. **Not now:** surface optical flow, sphere registration, full 3D feature
   tracking, deep regression. Each needs larger balls, higher fps or labelled
   data we do not have. Revisit deep regression once there are 100+ labelled
   throws.

### Marker choice

- **Default: no tape**, using whatever the ball shows. The grip holes are
  always present, dark and one cluster per revolution. Ship this only behind
  the confidence gate, and only if the alley truth agrees.
- **Offer a "tape mode"** for best accuracy: one strip of contrasting tape
  (white on dark balls, dark on light balls) running from the PAP out past the
  finger holes, stopping ~1 in short of the track. This is the USBC layout. It
  gives a strong flash *and* a readable clock hand.
- **Fix the checklist.** "Strip near your PAP" should become "strip from your
  PAP outward past the finger holes". Tape at the PAP alone will read as
  "no signal".

### FPS

- 30 fps can work in principle: Nyquist is 16 fps for 480 RPM. But it leaves 4
  to 7 samples per revolution, and the synthetic tests already show a floor at
  450 RPM.
- 60 fps is the minimum for the brightness method.
- 120 fps is the target for marker tracking.
- 240 fps is ground truth.

Shutter time matters as much as frame rate.

### Refuse to answer when

- Coverage in the early window is below 60%, or there are fewer than ~3 full
  revolutions in it.
- Ball radius is below ~20 px across the window. Below ~40 px, refuse the
  marker method.
- Split halves disagree, or the sub-harmonic test is ambiguous (f vs 2f).
- The estimate is outside 120 to 600 RPM, or outside the trajectory physics
  bound.
- Early and slightly later windows disagree by more than ~15% downward. Rev
  rate cannot fall during the skid.
- Exposure or white balance changed mid-window, or there are clipped highlights
  on the ball.
- 30 fps capture with an estimate above ~420 RPM. Say "use 60 fps or higher".
- A plain, featureless ball where the descriptor variance is at the noise
  floor. Suggest tape mode.

### Is rev rate a differentiator?

Partly:

- LaneTrax already lists rev rate, so "we have it and they don't" is false.
- Striker could not be verified.
- The real gap is a rev rate that is automatic, per throw and **validated with
  a published error**. Nobody publishes one, Specto included.
- Our November complaint research said "rev rate that looks wrong" is the top
  complaint. A number that refuses when unsure, plus a published "±N RPM vs
  240 fps hand count on M throws", is the pitch.

## 6. Validation protocol for the alley session

**Setup**

- Phone A (16 Pro): the app at its normal placement.
  - Record the rev rate set at 60 fps in-app.
  - If time allows, record a few throws with the native Camera at 120 fps
    (4K) slo-mo from the same spot. This tests the high-fps path before any
    code exists.
- Phone B (14 Pro): 240 fps slo-mo.
  - Place it low and just behind the foul line, to the bowler's **non-ball
    side rear** (left rear for a right-hander), as in the Kegel patent.
  - Frame tight on the first ~6 ft of lane so the ball is large.
  - Lock exposure (long-press AE/AF lock) on a lit lane.
- Sync: one sharp clap or a phone flashlight blink visible to both phones at
  the start of each throw. Or use the release frame, which both phones can see.
- Note per throw: ball, tape on or off, which phone or fps, and anything odd.

**Ball prep**

- Mark the PAP with a dot.
- Tape set: one strip from the PAP outward past the finger holes (see above).
- Photograph the ball from 4 sides, so we know where the graphics sit relative
  to the grip. This answers whether there are two flashes per revolution.

**Throws** (replaces checklist section 5)

- 6 taped throws: phone A at 60 fps, phone B at 240 fps.
- 6 untaped throws, same ball, same setup.
- 3 to 4 throws deliberately varied: one softer with fewer revs, one with more
  hand. This spreads the RPM range so the comparison is not just one point.
- If a second ball with different graphics is available, 3 untaped throws with
  it.

**Truth extraction at home** (per 240 fps clip)

1. Find the first frame after the thumb and fingers clear.
2. Find the frame where the tape (or a hole) returns to the same clock position
   for the 1st, 2nd and 3rd time.
3. RPM = 60 × 3 / ((frame3 − frame0) / 240).
   - Error: ±1 frame at each end over ~140 frames is about ±1.5%, so ±5 RPM
     at 300 RPM.
4. Have two people count independently, or count twice a day apart. Accept the
   truth only if the counts agree within 2%.
5. If the slo-mo also sees the ball at ~15 to 20 ft, count one more revolution
   there. This measures the down-lane rise directly.

**Comparison**

- Run extract and estimate on phone A clips three ways:
  - the current 2.2 s window,
  - the 0 to 0.9 s window,
  - the high-fps clips, if shot.
- Table per throw: truth, FFT estimate, error, confident yes/no, flashes-per-rev
  verdict.

**Pass bar**

- Taped, early window: confident on at least 5 of 6, every confident answer
  within ±25 RPM, median absolute error ≤10 RPM.
- Untaped: same bar for shipping marker-less by default. Otherwise ship tape
  mode only, with marker-less as "estimate".
- Zero confident answers at 2× or 0.5× truth. That would be harmonic error.
- If the 2.2 s window reads consistently 10% or more above truth while the
  early window does not, the down-lane bias is confirmed. Make the early window
  the definition.

## Sources

Products and methods
- https://www.spectobowling.com/frequently-asked-questions
- https://www.spectobowling.com/specto-terms
- https://www.spectobowling.com/specto-ranking-report-dec-2019
- https://forum.maverickbowling.com/viewtopic.php?t=14698
- http://www.bowlingboards.com/archive/index.php/t-22363.html
- https://patents.google.com/patent/US6110052
- https://images.bowl.com/bowl/media/legacy/internap/bowl/equipandspecs/pdfs/articles/ResearchcompleteonUSBCBowlingBallMotionStudy.doc.pdf
- https://apps.apple.com/app/id6475736816 (LaneTrax)
- https://docs.lanetrax.app/ios/newsessions/classic-mode
- https://www.lanetrax.app/
- https://apps.apple.com/us/app/bowlsense/id6760173811
- https://www.bowlsense.io/speed
- https://www.bowlsense.io/shop
- https://apps.apple.com/app/id1390556454 (Tenpin Toolkit)
- https://apps.apple.com/us/app/-/id6757426359 (Strike Zone)
- https://strikee.app/
- https://www.stormbowling.com/f5-bowling-sensor
- https://www.f5bowling.com/shop/f5-bowling-sensor
- https://bowlinglife.eu/lithuanian-company-witsee-bowling-sensor
- https://lanecaddie-website.pages.dev/
- https://ycpcs.github.io/cs400-fall2023/projects/RevMetrix-Project/Hake-MEngESci-Masters-Thesis.pdf

Coaching and physics
- https://bowl.com/what-s-your-rev-rate
- https://forum.maverickbowling.com/viewtopic.php?t=12829
- https://en.wikipedia.org/wiki/Bowling_form
- https://www.bowling.com/knowledge-hub/bowling-balls/bowler-types/all
- https://www.stormbowling.com/page-building-4
- https://www.researchgate.net/publication/243492690_What_makes_bowling_balls_hook
- https://images.bowl.com/bowl/media/legacy/internap/bowl/equipandspecs/pdfs/BallMotionAnalysisFormInstructions.pdf
- https://www.stormbowling.com/read/better-bowling-psa-pap-tips
- https://www.bowlingball.com/BowlVersity/the-importance-of-the-positive-axis-point

Spin estimation literature
- https://www.jstage.jst.go.jp/article/ijnc/16/2/16_166/_article/-char/en (smartphone baseball spin, 2026)
- https://www.mdpi.com/2076-3417/12/11/5540 (baseball spin from broadcast via Magnus fit, 7.5% error)
- https://arxiv.org/pdf/2303.03879.pdf (SpinDOE)
- https://cs.paperswithcode.com/paper/spin-detection-in-robotic-table-tennis
- https://arxiv.org/abs/2404.09870v1 (event-camera table tennis spin)
- https://www.arxiv.org/pdf/2504.19863 (broadcast table tennis spin, synthetic training)
- https://ir.lib.hiroshima-u.ac.jp/00020427 (Tamaki, spin by image registration)
- https://www.scitepress.org/Papers/2011/33727/ (Szép, rotation from arbitrary features)
- https://boracchi.faculty.polimi.it/docs/2009_09_09_InstantaneousBall3DMotion_Boracchi.pdf
- https://lida.sport-iat.de/twm/Record/4059923?lng=en (tennis spin, trajectory model vs Hawk-Eye)
- https://www.si.com/mlb/2023/11/15/how-it-works-mlb-pitch-tracking-baseball-statcast
- https://mygolfspy.com/news-opinion/rapsodo-mlm2pro-takes-spin-measurement-to-pro-level/
- https://arxiv.org/abs/2006.15418 (RepNet, repetition counting)

iPhone capture
- https://apple.com/sa/iphone-16-pro/specs
- https://www.macrumors.com/how-to/iphone-16-pro-shoot-4k-video-120-fps-slow-mo/
- https://developer.apple.com/tutorials/data/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:).md
