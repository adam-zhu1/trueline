# Accessibility (Nov 3, 2026)

What the v1.1 pass covered, what still doesn't work, and which App Store
Accessibility Nutrition Labels we can honestly declare. Apple's rule for a
label: every common task in the app works with that feature on. Common
tasks here are onboarding, recording a throw, calibrating, reading the
result, browsing history and stats, changing settings, and buying.

## What was done

**VoiceOver**
- Every metric tile reads as one sentence with spoken units, for example
  "Entry Angle, 5.2 degrees, in the target range of 4 to 6". Unmeasured
  metrics say "not measured" instead of "dash dash".
- The lane drawing on the result screen speaks a summary of the path:
  where it crosses the arrows, where it breaks, and where it enters,
  including whether that's the pocket. Built by `AccessibilityText`, which
  has unit tests.
- Home: the stat strip, the speed trend and the lane hero each read as one
  element. Stats: tiles and hero combine, chart bars and trend points have
  labels and values, decorative bands are hidden.
- History and session rows are one stop each.
- Close buttons on record, review, replay and paywall have labels. The
  replay video is exposed as a button.
- The analysis screen no longer hides its Cancel button from VoiceOver.
- Clip review announces when the drift check finds the phone moved, since
  that changes what the main button does.
- Onboarding and paywall illustrations are hidden; their text carries the
  meaning. The hand choice reads as "Left hand" or "Right hand", selected.

**Larger Text**
- The shared primary and secondary buttons grow and wrap instead of
  clipping (minimum height 54, not fixed).
- Fixed point sizes on text were replaced with text styles (home stat strip
  and speed trend) or `@ScaledMetric` with a cap (home headline, stats
  hero). The analysis percent counter stays fixed at 104 pt on purpose.
- Onboarding pages scroll when the text outgrows them, and the paywall
  scrolls at the accessibility sizes.

**Contrast**
- Muted text on the dark background was as low as 3.8:1. Every text color
  is now at least white at 55% opacity (about 6:1), above WCAG AA's 4.5:1.
  Mint on the dark background is 11.6:1.
- The "older version" tag and the metric target caption used tertiary or
  faded secondary styles and now use plain secondary.

**Reduced Motion**
- Already in place before this pass: the launch curtain, the result reveal,
  the home entrance and hero draw-in, the calibration pulse and the analysis
  counter all have reduced versions. This pass added the onboarding hand
  flip.

**Touch targets**
- Close buttons, the analysis cancel button, the zoom chips, the target
  button and the text links on clip review and the paywall now have 44 pt
  touch areas.

**Copy**
- Removed em dashes from user-facing strings, and fixed the onboarding
  calibration page, which still described the old four-corner flow.

## What isn't supported

- **Calibration with VoiceOver.** Calibrating means touching exact spots on
  a video frame, which VoiceOver's focus model can't do. The frame is marked
  for direct interaction, so touches pass straight through with VoiceOver
  on, and it reports how many points are placed. In practice a VoiceOver
  user needs a sighted helper for the first calibration of a session. Later
  throws reuse it, and the drift check corrects small bumps without new
  taps.
- **The replay video and the record preview** are camera images. VoiceOver
  can't describe the ball's motion in them; the lane summary and the
  metrics carry the result.
- **Charts** have per-mark labels but no audio graphs
  (`accessibilityChartDescriptor`).
- Not yet tested on a device with VoiceOver and the largest text sizes, only
  built and checked in code. Do that before declaring any label.

## Nutrition Labels we can declare

After a device check of the flows above:

- **Dark Interface:** yes. The app is dark throughout.
- **Reduced Motion:** yes. Every brand animation has a reduced version.
- **Sufficient Contrast:** yes. All text is at least 4.5:1.
- **Larger Text:** yes, if the device check at the largest accessibility
  size finds no clipped text on the common tasks.
- **VoiceOver:** no, not yet. Calibration is a common task and needs sight.
  Revisit if calibration ever gets a non-visual path, for example reusing a
  saved calibration from a previous session at the same lane.
- **Voice Control, Captions, Audio Descriptions, Differentiate Without
  Color:** not evaluated. There's no audio content, so captions and audio
  descriptions don't apply. Pocket hits are shown with color plus the
  number, but this wasn't audited screen by screen.
