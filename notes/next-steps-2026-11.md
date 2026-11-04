# Next steps, November 2026

Written Nov 1 after a research pass on competitors, user complaints,
tracking techniques and distribution.

## Where things stand

- 1.0 has been live since Aug 24, unadvertised, with 2 ratings. It still has the
  contact-point bug fixed on Sep 7, so its numbers read several boards to one
  side.
- 1.1 is built. Since Nov 1 it also has the 60 fps tracker fix, the far-lane
  focus crop, one shared lane model with the arrow and half-board fixes, a unit
  test target and 25 free throws.
- The alley validation session has not happened yet. It is the gate for 1.1.

## What the research said

**Competitors.** LaneTrax is the main one: about 665 ratings at 4.8 stars,
$9.99 a month or $89.99 a year. Its developer calls its rev rate a work in
progress. Striker: Bowling Coach appeared in August with nearly our feature
set (4-corner calibration, path, entry, speed, spare suggestions) for
$19.99 a year and no rev rate. Specto's own app is rated 3.0 and bowlers pay
about $10 a session to use Specto at a center. Rev rate sensors cost around
$319 and none are approved by USBC.

**What bowlers complain about,** from competitor reviews, strongest first:
rev rate that looks wrong, setup that breaks when the tripod is bumped,
subscriptions, numbers that don't match the replay, and no way to add notes or
export data. One-time pricing and the drift overlay already answer two of
these. A rev rate with published accuracy would answer the biggest one.

**Pricing.** One-time is right for this audience. $14.99 is low next to what
bowlers already pay, so try $19.99 to $24.99 once rev rate ships. Promo codes
for in-app purchases were retired in March 2026, so creator and pro shop codes
have to be offer codes. Test one before handing any out.

**Timing.** League season runs September to April. The best window to promote
is January and February, ahead of the USBC Open Championships (Feb 27 to
Jul 24, 2027, Las Vegas).

## Order of work

1. **Alley session.** Follow `alley-visit-checklist.md`, and also:
   - record a few throws at 60 fps in the app, to confirm the tracker fix on
     native footage (so far it is only proven on a 60 fps screen recording);
   - include one tilted or off-center placement, to check the focus crop's far
     lane accuracy. IMG_5115 now tracks to 59 ft but reads entry 20.4 while
     the pin action looks closer to the pocket, so the rescued points may be
     biased by a board or two;
   - shoot a second phone at 240 fps for rev rate truth.
2. **Ship 1.1** with the listing changes in `app-store-listing.md`.
3. **TestFlight beta** with 10 to 30 local bowlers (the Pitt Bowling Club and
   Robert Morris club bowling are nearby). Collect phone model, fps, placement
   photos and center-displayed speed to compare against.
4. **Rev rate in the app,** if the 240 fps counts agree with the FFT readings.
5. **Per-throw drift detection** with Vision image registration, so a bumped
   phone is caught automatically instead of only being visible in the overlay.
6. **Notes and CSV export** per session.
7. **Detector retraining** with perspective and blur augmentation, once the
   alley session adds new footage.

## Known issues not yet fixed

- Launch speed on a 60 fps screen recording reads 15 mph against 18.6 at
  30 fps. Both versions show the ball speeding up down the lane, which is a
  calibration or footage problem on that clip, so it needs native footage to
  judge.
- Batch-2 alley clips 5112, 5113 and 5114 still barely detect the ball. The
  focus crop only helps once a track has locked.
- Saved shots from 1.0 keep their old, shifted numbers. `SavedShot` has no
  analyzer version field to flag them.
