# Rev rate plan

Written Nov 15, 2026. This is the decision document for shipping rev rate in a
version after 1.1. It builds on `rev-rate-research.md` (Nov 1, the long
research pass), the harness in `experiments/rev_rate/` and the protocol in
`alley-visit-checklist.md`. It does not repeat the product survey or the
technique literature from the research note. Read that for sources on CATS,
LaneTrax, sensors and sports spin papers.

## The recommendation

Build rev rate as a **measured release rev rate**. It is read from the first
~20 ft of the lane, from video captured at 120 fps with a short shutter. It
uses appearance periodicity as the main method and marker angle tracking as
the check. Ship it only if the alley truth clips say it works, and refuse to
show a number whenever the checks disagree.

Three things decide whether this is feasible. They are explained below.

1. **Pixels on the ball limit this more than frame rate does.** At the app's
   1080p capture the ball is only about 27 to 28 px in radius when tracking
   first locks on (from the extractor's radius model on the batch-1 clips).
   A finger hole is then about 5 px across. Even 30 fps is above Nyquist for
   every realistic rev rate, so a higher frame rate mainly buys shorter
   exposures and smaller rotation per frame. It does not buy detail. Tape
   (about 44 px long at that size) is readable. Bare finger holes are
   marginal. The ball's own graphics only work as a whole-ball brightness
   or appearance signal.
2. **1080p at 240 fps is reachable from inside the app. 4K at 120 fps is
   not something to rely on.** The app already picks a 1080p format by
   dimensions and sets a fixed frame duration (`CameraModel.requestSixtyFPS`).
   Apple's capture technote says high frame rates are reached by choosing a
   device format whose `videoSupportedFrameRateRanges` include the rate,
   then setting the frame durations. Its 240 fps example uses a binned
   format ([TN2409](https://developer.apple.com/library/ios/technotes/tn2409/_index.html)).
   A developer on Apple's forums reports that a custom app records 1080p up to
   240 fps on an iPhone 16 Pro, while 4K at 120 fps gives a black preview and
   black files. That thread has no answer
   ([Apple forums 772769](https://developer.apple.com/forums/thread/772769)).
   So plan on 1080p120 as the default capture for rev rate, with 1080p240 as
   an option. Treat 4K120 as unproven in third-party apps until a format dump
   on Adam's phone shows otherwise.
3. **Nobody else has a validated number, and the leading system admits its
   number is inferred.** Specto's tutorial calls RPM "a calculated number
   that calculates the revs of the player based on a number of factors"
   ([Specto tutorial](https://www.spectobowling.com/tutorialperformance)). It
   is read from lidar path data, not seen on the ball. Kegel's own chart
   material says the calculation assumes constant friction and that the
   numbers "may vary depending upon the bowling ball" (quoted in search
   results for Kegel's Specto PDF; the box.com file would not load here). The
   opening for TrueLine is a rev rate that is **measured off the ball and
   comes with a published error figure**. A number with no error figure
   would only be the fifth one on the App Store.

## What rev rate means to the bowlers who would use it

Rev rate is revolutions per minute of the ball, taken right after release.
USBC's guide says the truest reading is immediately after release, and that
counting rotations down the whole lane gives "revolutions per shot and not
revolutions per minute" ([USBC, What's Your Rev Rate](https://bowl.com/what-s-your-rev-rate)).

| Style | Typical RPM | What they want from the number |
|---|---|---|
| Stroker | under about 300 | Proof that their ball choice matches their hand. Low-rev players need stronger covers and earlier-reading balls, and often play straighter lines. Many want to add a few revs without losing accuracy. |
| Tweener | about 300 to 400 | Most league bowlers. They use the number to compare against friends and to judge whether a ball recommendation fits them. Week-to-week change matters to them if they are working on their release. |
| Cranker | 400 and up | Control rather than more. They want to see whether revs stay steady late in a set, and how the rev rate matches their speed. |
| Two-handed | often 450 to 600+ | The highest numbers, and the ones that 30 fps video handles worst. |

Ranges from [BowlerSmart](https://www.bowlersmart.com/2021/03/22/the-basics-of-bowling-ball-motion-surface-speed-rev-rate-tilt-and-rotation/)
and [Wikipedia, bowling form](https://en.wikipedia.org/wiki/Bowling_form);
see also `bowling-knowledge.md` section 3.

**Rev rate only matters next to speed.** A high-rev bowler throwing slowly
hooks too early, and a low-rev bowler throwing hard hooks too late. Bowling
This Month uses a "rev rate optimization score": RPM divided by speed in mph.
Above 25 is rev-dominant, below 20 is speed-dominant, and 20 to 25 is
balanced. It suggests a high-level bowler aim for 22 to 27
([BTM, Tyrel Rose](https://www.bowlingthismonth.com/bowling-tips/five-ways-to-improve-your-release-part-2/)).
TrueLine already measures launch speed on the same throw, so it can show this
ratio without the bowler doing any math. No phone competitor shows it.

How a bowler would actually use the number:

- **Pick equipment.** Bowlers and pro shops classify players by speed and rev
  rate before recommending a ball. A pro shop would use this when drilling.
- **Track a release change** over weeks. This needs session medians that are
  good to about ±10 RPM.
- **Check consistency.** A rev rate that drops in game three is a sign of
  fatigue or a changed release. The per-throw spread matters here more than
  the absolute value.
- **Compare against Specto** at a center that has it. Expect disagreement,
  because Specto's RPM is computed from ball motion.

Accuracy needed (from the research note): per throw within ±25 RPM, session
median within ±10 RPM. The style buckets are about 100 RPM wide, so ±25 is
enough to classify. USBC's own 30 fps clock method is only good to about
±15 RPM.

## Sampling: what each frame rate gives

Rev rates of 200 to 600 RPM are 3.3 to 10 rev/s. Nyquist needs at least 2
samples per revolution, so 20 fps covers 600 RPM. Every capture rate clears
that. The problems are elsewhere.

| fps | Frames per rev at 200 / 400 / 600 RPM | Rotation per frame at 600 RPM | Longest shutter possible | Main limit |
|---|---|---|---|---|
| 30 | 9 / 4.5 / 3 | 120° | 1/30 s | A two-graphic ball (two flashes per rev) at 8 rev/s puts its 16 Hz flash above the 15 Hz Nyquist limit. It aliases to 14 Hz, which the harmonic check reads as 7 rev/s (420 RPM instead of 480). The harness already refuses readings above 420 RPM at 30 fps, and this alias is one more reason to keep that rule. Marker tracking is ambiguous at 120° per frame. |
| 60 | 18 / 9 / 6 | 60° | 1/60 s | Blur. At 300 RPM a point on the ball's equator moves about 3.4 m/s, so a 1/60 s auto exposure smears it about half a ball radius. The brightness method survives this. Marker tracking does not. |
| 120 | 36 / 18 / 12 | 30° | 1/120 s, shorter if locked | Light. A 1/500 s shutter in a dim center needs high ISO. Workable on lit lanes. |
| 240 | 72 / 36 / 24 | 15° | 1/240 s | Light and noise, and the format may be binned (less real detail per pixel). Use it for ground truth from a second phone. |

**Expected accuracy per fps**, for a clean, tracked throw. These are
estimates from the synthetic gate and from timing arithmetic. The alley data
will replace them.

- Timing noise is small at any rate. Locating 4 revolutions end to end to
  ±0.5 frame at 60 fps (about 48 frames for 4 revs at 300 RPM) is about ±1%,
  or ±3 RPM. A least-squares fit of marker phase over 0.8 s gives under
  ±2 RPM of random error at 120 fps or more.
- The real errors are bias, and none of them get better with fps:
  - the wrong harmonic (reading 2× or 0.5× the truth),
  - measuring too far down the lane (rev rate rises 10 to 50% once the ball
    leaves the skid; see the toy model table in the research note),
  - variable frame timing in the file (use presentation timestamps, never a
    nominal fps),
  - axis migration blurring the period late in the window.

| Capture | Method | Expected per-throw error when it answers | How often it should answer |
|---|---|---|---|
| 30 fps, untaped | brightness FFT | ±25 to 40 RPM; refuse above 420 | low, many refusals |
| 60 fps, untaped | brightness or descriptor period | ±15 to 25 RPM | medium; depends on the ball's graphics |
| 60 fps, taped | descriptor period | ±10 to 20 RPM | high |
| 120 fps, taped | descriptor period confirmed by marker angle | ±5 to 15 RPM | high on lit lanes |
| 240 fps, taped, second phone, hand count | human count of 3 revs | ±5 RPM (±1 frame per end over ~140 frames) | ground truth only |

## Candidate methods

| Method | How it works | Verdict |
|---|---|---|
| **Appearance periodicity** (current harness, upgraded) | Mean brightness of the ball crop, or better a 16×16 or sector descriptor per frame. Find the period with a harmonic-weighted FFT plus a self-similarity check. Already gated by split-half agreement. | **Primary.** It survives blur, works with tape or graphics, and costs almost nothing on device. Batch-1 clips read a confident 328 to 380 RPM on untaped throws. |
| **Marker angle tracking** (the automated clock-hand method) | Find the tape's outer end, or the grip holes, and track its angle around the ball center frame by frame. Unwrap the phase and fit a line. This is the same structure as the 2026 smartphone baseball method (5.7% mean error, 90% success; [Yamamoto and Matsumae](https://www.jstage.jst.go.jp/article/ijnc/16/2/16_166/_article/-char/en)). | **Check and tape mode.** It removes harmonic ambiguity, because it sees each revolution. It needs a radius of 30 px or more and 120 fps or more, so it covers only the first 10 to 15 ft. |
| **Optical flow on ball texture** | Vision's `VNGenerateOpticalFlowRequest` on consecutive ball crops. Rotation shows up as a flow field around the spin axis. | **Not now.** It needs sharp texture that persists between frames. At 28 px and 1/60 s, there is none. Revisit only if a 4K or closer near-field crop becomes possible. |
| **Track curvature physics** | Friction changes spin by (R/k²) × the change in velocity. From launch velocity, roll-out velocity and a default RG of about 2.5 in, solve for release spin. This is the Specto-style inference. | **Plausibility bound only.** It cannot see axis rotation, it needs the ball to reach roll before the pins, and a 0.1 m/s speed error moves the answer by about 30 RPM. Use it to refuse impossible readings, like the old 109 RPM on clip 5105. Never show it as the number. |
| Deep regression from frames | Train a model on labelled throws. | **Later.** Needs 100+ labelled throws. The beta could produce them (see below). |

## Ground truth to collect at the alley

The session in `alley-visit-checklist.md` section 5 and the protocol in
`rev-rate-research.md` section 6 stand. What this plan adds:

- **Phone B (the 240 fps phone) goes low and beside the foul line on the
  non-ball side, a little behind the bowler.** The Kegel patent puts its
  spin camera at the left rear for a right-hander so the axis and tape stay
  in view ([US6110052](https://patents.google.com/patent/US6110052)). Frame
  tight on the first 6 ft. Lock exposure with a long press.
- **Tape layout:** one strip of white tape (or dark tape on a light ball)
  from the PAP out past the finger holes, stopping about an inch short of the
  track. This is USBC's layout. Tape on the PAP alone barely moves and gives
  no signal.
- **Phone A (the app phone)** records the same throws in the app at 60 fps.
  Then record a few at 120 fps and 240 fps in the stock Camera app's slo-mo
  from the app's tripod spot. This tests the high-fps path before writing
  any capture code. Import those into the harness on the Mac.
- **Spread the range.** Use several bowlers with different styles if
  possible, from a stroker up to a cranker or two-hander. Otherwise have one
  bowler vary the release from soft to extra hand. The pass bar is meaningless if every throw is 350.
- **Count:** 6 taped and 6 untaped per bowler is the minimum. 30 throws in
  total is enough to publish "median error N RPM on 30 throws".
- **Count truth twice.** Two people, or one person on two days, and keep a
  throw only if both counts agree within 2%.
- **Keep the stock slo-mo files intact.** AirDrop with "All Photos Data" on,
  so the 240 fps timing metadata survives. A file that plays back at 30 fps
  with a slow-motion ramp has edited timestamps.

## UX: when to show a number and when to refuse

**Label it for what it is.** "Rev rate (release)" with a small "measured in
the first 20 ft" line in the detail view. Show "about 340 RPM", rounded to
the nearest 10. The accuracy target is ±10 to 25, so a last digit would be
false precision.

**Refuse, and say why,** when any of these hold:

- fewer than 3 full revolutions inside the early window,
- ball radius under 20 px in the window, or tracking coverage under 60%,
- split-half disagreement, or the FFT and the marker phase disagree by more
  than 10%,
- the reading is outside 120 to 650 RPM, or outside the physics bound for
  this throw's speed,
- 30 fps capture with a reading above 420 RPM ("Record at 60 fps or higher
  for high rev rates"),
- the exposure or white balance changed during the window, or the ball is
  clipped to white,
- a featureless ball where the descriptor shows no structure ("Add a strip of
  tape from your PAP past the finger holes").

The refusal text should match the existing tracking-failure screens: one
cause, one fix, no blame. A refusal never uses a free throw. The other
metrics on the throw still show.

**Session view:** show the median rev rate of the throws that answered and
the count ("median 335 RPM from 9 of 12 throws"). Show the RPM-to-speed
ratio from the session medians, with BTM's bands as plain text ("balanced",
"rev-dominant", "speed-dominant").

**Tape mode:** a toggle on the record screen ("Ball has a tape strip"). It
switches marker tracking on as a primary method and tightens the gates.
Include a one-screen picture of where to put the tape. No other setup.

**Copy rules:** say "measured", never "accurate" or "pro". Publish the
alley result on truelinebowling.com in one line ("Within N RPM of a 240 fps
hand count on 30 throws") with the date. Add "rev" and "rpm" to the keywords
and change the subtitle only on the version that ships it (guideline 2.3.1).

## Staged build plan

Effort is Adam's focused working days. Stages 0 to 2 happen on the Mac with
no app changes, so nothing ships until stage 5.

| Stage | Work | Effort | Exit test |
|---|---|---|---|
| 0. Device facts | A debug-only dump of `device.formats` on the 16 Pro: dimensions, max fps, binned flag, field of view, ISO and exposure range for each 1080p and 4K format at 120 and 240 fps. Run it once at home, once at the alley. | 0.5 day | We know which formats exist, whether 1080p240 is binned or cropped, and how dark 1/500 s is at the alley. |
| 1. Truth set | The alley session above, then hand-count truth for every 240 fps clip. Store as `experiments/rev_rate/truth.csv`. | 1 alley visit + 1 day counting | 20 or more throws with double-counted truth. |
| 2. Harness upgrade | Descriptor self-similarity, sub-harmonic test (fold at 2T), physics bound, early window from first detection, use real timestamps. Score against truth. | 2 to 3 days | Taped, early window, at least 5 of 6 confident; each confident answer within ±25; median error 10 or less; no 2× or 0.5× errors. |
| 3. Marker tracker | Tape-end and grip-hole angle tracking on the 120 and 240 fps clips, with phase unwrap and line fit. Compare with stage 2. | 2 to 3 days | Agrees with truth within ±15 on taped throws at 120 fps. |
| **Decision gate** | Ship tape mode only, ship both modes, or stop. See below. | | |
| 4. App capture | Rev rate capture mode: 1080p at 120 fps (240 if stage 0 says it isn't binned), shutter locked at 1/500 s or the shortest the light allows, ISO capped. The tracker runs on every 2nd or 4th frame and the ball center is interpolated for the crops. Check heat and file size on a 12-throw session. | 3 to 4 days | A 120 fps session tracks as well as 60 fps did on the same lane. |
| 5. App estimator and UX | Port the estimator to Swift with vDSP FFT and a unit test that replays the harness signals. Refusal screens, tape mode toggle, session median, ratio to speed, CSV column. | 4 to 5 days | Swift output matches Python within 2 RPM on every stored signal. Reviewer-perspective script passes. |
| 6. Beta validation | TestFlight to the clubs (see `beta-outreach.md`) with a request for taped throws plus a friend's slo-mo clip. Count those for truth too. | 2 to 3 weeks elapsed, about 2 days of work | Error on testers' throws within the alley figure. Then publish the number and submit. |

Total: about 13 to 18 working days plus the alley visit and a beta round.
Realistic target: a 1.2 build in TestFlight in February, in time for the
promotion window before the spring tournaments.

### Decision gate after stage 3

- **Untaped passes the bar:** ship rev rate on by default, with tape mode as
  the "for best accuracy" option.
- **Only taped passes:** ship tape mode only. Untaped throws show "Add tape
  to measure rev rate" rather than a guess.
- **Taped fails at 120 fps:** do not ship automatic rev rate. Ship a manual
  helper instead: a frame stepper on the replay where the bowler marks the
  tape at two moments, and the app does the arithmetic with real timestamps.
  Tenpin Toolkit and Strike Zone already do this by hand, so it is honest
  but not a selling point. Revisit after detector retraining improves near-lane
  ball size, or if 4K120 turns out to work.

### Pricing note

`next-steps-2026-11.md` suggests moving to $19.99 to $24.99 once rev rate
ships. Raise the price only after the published accuracy figure exists. The
price change and the subtitle change should go out on the same version.

## Open questions for Adam

1. Is a capture mode switch (60 fps normal, 120 fps rev rate) acceptable on
   the record screen? The feedback note on minimal capture guidance argues
   for one small toggle at most, and no new overlays.
2. Who can be the second and third bowler at the alley session? One bowler
   cannot cover the RPM range.
3. Does the 14 Pro still record 240 fps slo-mo reliably? Some Apple
   Community threads report phones capped near 180 fps in slo-mo
   ([thread](https://discussions.apple.com/thread/254434880)). Check before
   the alley trip. 120 fps truth is acceptable if needed: ±1 frame at 120 fps
   over 3 revs is about ±3%.
