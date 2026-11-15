# App Store listing — working draft

Internal draft — lives outside docs/ so GitHub Pages never serves it.
Final text goes into App Store Connect after enrollment.

## 1.1 submission (final, paste-ready)

Written Nov 15, 2026 against the v1.1 source (version 1.1, build 3). This
section replaces the change list below it; everything in that list is applied
here. Character counts were measured on the exact text in each block. Paste the
text inside the code blocks, not the fences.

Rules this text follows, from `launch-plan-1.1.md` section 4: no "pro-accurate"
or board-level accuracy claims, no "thousands", no USBC, PBA or Specto, no
prices or free-throw counts in screenshots, and rev rate stays out until it
ships.

### Name (30 max), unchanged

```
TrueLine: Bowling Ball Tracker
```

30 characters.

### Subtitle (30 max)

```
Speed, entry angle, breakpoint
```

30 characters. From the launch plan: the subtitle carries more search weight
than the keyword field, and "breakpoint" moves here from the keywords. When rev
rate ships, change it to "Speed, rev rate & entry angle" (29).

### What's New in This Version (4,000 max)

```
This update fixes how the ball's position is measured. Version 1.0 read every throw several boards to one side. Throws saved before this update are marked in History so you know which numbers to trust.

Calibration is now six taps on the lane markings. You can also record at 2x, which makes the far end of the lane easier to see.

Each throw is checked against your calibration. If the phone gets bumped a little, TrueLine corrects for it. If it moved a lot, you'll be asked to recalibrate.

The ball is tracked farther down the lane, including in 60 fps video.

When a throw can't be tracked, TrueLine tells you why and what to try. Those throws don't use a free throw, and you now get 25 free throws instead of 10.

You can export your throws as a CSV file from History or from any session. Settings has new links to rate the app and to send feedback.

The app also works better with VoiceOver and with larger text sizes.
```

924 characters.

### Promotional text (170 max, editable any time without review)

```
Set your iPhone behind the approach and see ball speed and entry angle on every throw. Your first 25 throws are free, and one purchase unlocks the rest for good.
```

161 characters. It mentions 25 free throws, so change it only once 1.1 is live
(1.0 still gives 10). Until then the 1.0 promo text stays, minus "Pro-style"
if you want it out sooner.

### Description (4,000 max)

```
TrueLine measures your bowling throws with one iPhone. Set it on a tripod behind the approach and bowl. A few seconds after each throw you see the same kinds of numbers that in-center tracking systems show, worked out on your phone.

WHAT IT MEASURES
• Ball speed and average speed
• Shot time
• Board at the foul line and at the arrows
• Launch angle
• Breakpoint board and distance
• Entry board and entry angle
• Total hook in boards, and hook factor
• Pocket hits

SEE YOUR GAME
• Your throw replayed with the tracked path drawn on it
• Every line of a session drawn on one lane view
• Trends across sessions for speed, hook, entry angle and pocket rate
• Stats by ball, so you can compare how each ball in your bag reacts
• Target-line practice: pick a board at the arrows and see how close each throw gets
• Share cards that turn any shot into an image
• CSV export of every throw, for a spreadsheet or your coach

SETTING UP
• Calibrate once per phone placement with six taps on the lane markings
• Each throw is checked against your calibration, and small bumps are corrected for you
• Record at 1x or 2x
• Works in most centers with the phone steady behind the approach
• Analyze videos you already have in your camera roll

Some tournaments don't allow recording, so check the event rules before you film.

PRIVACY
Everything runs on your iPhone. There is no account, and your videos and throws are never uploaded.

PRICE
Your first 25 throws are free. Only throws that analyze successfully count. After that, a one-time purchase unlocks unlimited throws. There is no subscription.
```

1,591 characters. What changed from 1.0: "the numbers serious bowlers pay
thousands to get" became "the same kinds of numbers that in-center tracking
systems show"; "Works at any center on any lane" became "Works in most centers
with the phone steady behind the approach"; 10 free throws became 25; the
metrics added in 1.1 (foul line board, average speed, shot time, hook factor)
are listed; CSV export, six-tap calibration, the bump check and 2x recording
are listed; the recording-rules line is there without naming any organization.

### Keywords (100 max)

```
trainer,coach,stats,analysis,meter,hook,arrows,league,practice,tenpin,lane,video,pocket,boards,pin
```

98 characters, 15 terms, commas and no spaces. None of them repeat a word from
the name (TrueLine, Bowling, Ball, Tracker) or the new subtitle (Speed, Entry,
Angle, Breakpoint). No trademarks. Dropped from 1.0: bowling and tracker (in
the name), pba and usbc (other parties' marks), rev (not shipped), strike and
spare (pull in games and score keepers), oil and pattern (the app doesn't read
oil). "pin" is the weakest term; swap it for "arsenal" if per-ball compare ever
leads the screenshots. Check App Analytics search terms 30 days after release.

### URLs

| Field | Where in App Store Connect | Value |
|---|---|---|
| Support URL | Version page, App Information | https://truelinebowling.com/support/ |
| Marketing URL | Version page (optional) | https://truelinebowling.com/ |
| Privacy Policy URL | App Privacy | https://truelinebowling.com/privacy/ |

Support email for the support page and the review contact:
support@truelinebowling.com (forwards to the trueline.app.help Gmail inbox).
From 1.1 the app's Settings links and Send Feedback use truelinebowling.com.
1.0 installs still link to adamzhu.dev/trueline and the github.io form, so both must keep
resolving (see "URLs" further down).

### App Privacy

Data Not Collected, unchanged. 1.1 adds no SDK and makes no network calls of
its own. Send Feedback only opens a draft in the user's own Mail app; the app
sends nothing itself, and the user decides whether to send the email. Apple's
optional-disclosure rules cover user-initiated feedback of this kind, but read
that section of the App Privacy help once before submitting to be sure.

### Accessibility Nutrition Labels

Declare these, per `accessibility.md`, after the device check it calls for:

| Label | Declare | Why |
|---|---|---|
| Dark Interface | Yes | Dark by default; recording, analysis and launch screens are always dark |
| Reduced Motion | Yes | Every brand animation has a reduced version, including the onboarding hand flip |
| Sufficient Contrast | Yes | All text at least 4.5:1 on the dark interface. See the open item below about the Light appearance setting |
| Larger Text | Yes, only if the device check passes | Text styles and scaled metrics throughout; needs a run at the largest accessibility size with no clipped text on the common tasks |
| VoiceOver | No | Calibration needs precise touches on the video frame, so a common task needs sight |
| Voice Control | No | Not evaluated |
| Differentiate Without Color Alone | No | Not audited screen by screen |
| Captions, Audio Descriptions | No | The app has no audio or narrated video, so there is nothing to declare |

Open item before declaring Sufficient Contrast: Settings has an Appearance
choice (Dark, Light, System). Dark is the default and is what the contrast pass
measured. Check the Light appearance on the common tasks too, or Apple's
"every common task" rule may not hold for someone who switches.

### Category and price, unchanged

Primary Sports, secondary Health & Fitness. TrueLine Unlimited
(`com.adamzhu.Trueline.unlimited`), non-consumable, $14.99 tier. The free
allowance is 25 successful analyses in 1.1.

### Screenshots

Plan in `launch-plan-1.1.md` section 1. Captions carry no price, "free" or
free-throw count (2.3.7). Upload both the 1320 x 2868 and the 1206 x 2622 sets.

## v1.1 changes to make at submission (Nov 1, 2026)

*Applied in the 1.1 submission section above. Kept as the record of what changed and why.*

Not live yet. Apply these in App Store Connect when 1.1 is submitted.

- **Free throws:** 10 becomes 25 (`TruelineStore.freeThrowLimit`). Update the
  description line, the review notes and docs/index.md at the same time, not
  before, since 1.0 still gives 10.
- **Overclaim:** "Works at any center on any lane" becomes "Works in most
  centers with the phone steady behind the approach". The detector still
  struggles with tilted placements.
- **Keywords:** drop bowling and tracker (already in the name) and pba and usbc
  (other parties' marks, a rejection risk). Candidates: ballspeed, entry,
  angle, breakpoint, arsenal, boards, practice, analyzer.
- **Release notes:** say plainly that 1.1 fixes how ball position is measured
  and that throws analyzed with 1.0 read several boards to one side. People who
  tried 1.0 should know the numbers changed for a reason.
- **Practice only:** add a line that recording is not allowed at some events
  (the USBC Open Championships bans it). League play has no rule against it.
- **Screenshots:** swap the first two for real footage with the tracked path
  once the alley session gives us clean clips.

# 1.0 listing (live since August 2026)

What 1.0 shipped with. Superseded by the 1.1 section above at submission.

## Name (30 chars max)

**TrueLine: Bowling Ball Tracker** (30)

## Subtitle (30 chars max)

**Speed, hook & entry angle** (25)

## Category

Primary: Sports · Secondary: Health & Fitness

## Price

$14.99 one-time (TrueLine Unlimited, non-consumable). 10 free analyzed throws.

## Promotional text (170 chars, editable without review)

Pro-style ball tracking without the pro-shop price. Prop your phone behind the
approach and get the numbers a coach would give you, on every single throw.

## Description

TrueLine turns your iPhone into a ball-motion tracker. Prop it behind the
approach and bowl. Seconds after each throw, you see the numbers serious
bowlers pay thousands to get, computed entirely on your phone.

WHAT IT MEASURES
• Ball speed
• Board at the arrows
• Launch angle
• Breakpoint board and distance
• Entry board and entry angle
• Total hook, in boards
• Pocket hits

SEE YOUR GAME
• Your throw replayed with the tracked path drawn on it
• Every line of a session fanned on one lane view
• Trends across sessions: speed, hook, entry angle, pocket %
• Compare your arsenal: per-ball speed, hook, and pocket rate
• Target-line practice: pick a board, get scored on hitting it
• Share cards: one tap turns any shot into a post-ready image

MADE FOR PRACTICE
• Calibrate once per phone placement, then just bowl
• Works at any center on any lane, no extra hardware needed
• Analyze footage you already have from your camera roll

PRIVACY
Everything runs on your iPhone. There is no account and no subscription,
and nothing is ever uploaded anywhere. Your first 10 throws are free.
A single purchase unlocks TrueLine forever.

## Keywords (100 chars, comma-separated, no spaces)

bowling,tracker,rev,hook,league,pba,usbc,lane,strike,spare,oil,pattern,tenpin,coach,speed

(94 chars. "bowling"/"tracker" also in the name — consider swapping for
"scorekeeper,arsenal" once search data exists.)

## Screenshots (6.9" required; plan)

Decision (Aug 15): screenshots are the real app UI showing seeded demo data
(`-seedDemoHistory`), captured on the iPhone 17 Pro Max simulator at
1320×2868. Compliant with 2.3.3 (actual UI in use), needs no lane time, and
keeps IG footage out entirely. Refresh with real-footage variants in an
update if we want them later. CAPTURED (Aug 15, evening timestamps): the
full set is in output/appstore-screenshots/ — home hero, history, session
consistency, session lines, shot result (lane + tiles), stats, first-run
home, two onboarding pages, and the 1080×1350 share card pulled straight
from the app's share pipeline. Upload-ready at 1320×2868.

1. Results screen — lane view with tracked path + metric tiles (hero)
2. Stats dashboard — throw count, entry histogram, per-ball bars
3. Session Lines view — all throws fanned on one lane
4. Home — session headline, sparkline, Start Session
5. Share card
6. Onboarding pocket diagram + "Which hand do you bowl with?"
7. (post-alley, optional) Calibration corner handles over real footage

The IG clips stay banned from every Apple-facing asset — we don't hold
rights to them. The App Review sample video still must be our own footage.

## Review notes (for App Review)

*Superseded: the 1.1 review notes are in `app-review-notes.md`.*

The app needs a bowling-lane video to demonstrate. A sample clip and steps
will be attached (record at field test). In-app purchase: TrueLine Unlimited,
non-consumable, unlocks unlimited analyzed throws after the 10 free ones.

## URLs

- Privacy: https://adamzhu.dev/trueline/privacy
- Support: https://adamzhu.dev/trueline/support

Both were registered with Apple in the `https://adam-zhu1.github.io/trueline/...`
form. That form still resolves — it 301s to adamzhu.dev — but check the live App
Store Connect entries, since the repo only records what was pasted, and no
marketing URL is recorded anywhere.

### Serving moved, 2026-09-11

These pages used to be served by this repo's own Pages site (`main` branch,
`/docs`, Jekyll). The portfolio repo (`adam-zhu1/adam-zhu1.github.io`) now owns
the whole `/trueline/*` path on adamzhu.dev, so this repo's Pages site was
deleted and the rendered privacy/support pages are mirrored there. `docs/` stays
here as the source of truth; re-mirror after editing.

Two things this constrains:

1. **adamzhu.dev must remain the custom domain on the user site.** The app's
   Settings links break if it ever changes, no matter which repo serves the path.
2. **The `adam-zhu1.github.io/trueline/` form has to keep resolving** for as long
   as any already-installed copy is in use. Copies shipped before v1.1 hardcode
   it (`SettingsView.swift`, the pre-f8119de version); an app update only
   repoints future installs. Verified after the cutover that the redirect
   survives the project Pages site being deleted: with a custom domain on the
   user site, `adam-zhu1.github.io/*` keeps redirecting to `adamzhu.dev/*` and
   the user site's own files serve the path.

v1.1 onward points Settings at adamzhu.dev directly (commit f8119de), which skips
the redirect hop for new installs but changes nothing for existing ones.
