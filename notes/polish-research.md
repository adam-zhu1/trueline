# Polish research: what TrueLine is missing next to well-reviewed apps

*2026-11-02. Research pass for the "feel like a real product" goal. Competitor
basics (LaneTrax, Striker, Specto, pricing, review complaints) are already in
`next-steps-2026-11.md` and `research-bowling-workflows.md` and are not repeated.*

## What the app already has

A quick audit of `ios/Trueline/Trueline/` so the gaps below are real gaps:

- **Onboarding:** 3 illustrated pages plus a bowling-hand picker. Camera
  permission denial is handled with a link to Settings (`RecordView.swift`).
- **Empty states:** `ContentUnavailableView` in History and Stats. Home has a
  separate first-run poster state.
- **Error states:** `TrackingFailedView` lists common causes and offers to
  adjust corners. It does not say which cause applied to this clip.
- **Haptics:** only in calibration (tap and success, `CalibrationView.swift`).
  Nothing on record start/stop, analysis done, or pocket hit.
- **Accessibility:** about 9 `accessibilityLabel`s, mostly icon buttons.
  `reduceMotion` is respected (20 call sites). Metric tiles use text styles, so
  they scale, but there are 23 fixed `.font(.system(size:))` calls. Metric
  tiles, the lane canvas and charts have no VoiceOver summaries.
- **Share:** a 1080x1350 share card via `ImageRenderer` + `ShareLink`.
- **Restore purchases:** present in both Settings and the paywall
  (`AppStore.sync()`). Good, this is required.
- **Storage:** SwiftData (`BowlingSession`, `SavedShot`), videos as files.
- **Missing entirely:** review prompt, in-app feedback, data export, widgets,
  Live Activities, Watch app, iCloud sync, What's New screen, TipKit,
  localization (no String Catalog), Accessibility Nutrition Labels.

## 1. Polish checklist

What top sports and fitness apps do that small apps tend to skip, and what it
would mean here.

### Onboarding
Strava, HomeCourt and SwingVision get you to the first real result fast and
teach setup in context instead of in a slideshow. TrueLine's short onboarding
is fine. The gap is that a new user cannot see the app work until they are at
a lane with a tripod. A **built-in sample clip** ("See a demo throw") fixes the
"downloaded at home, nothing to do" problem and also helps App Review. It must
be Adam's own footage (IG clips are banned from Apple-facing assets), so it
waits on the alley session. TipKit (iOS 17+, matches our deployment target) is
the native way to teach features like the session lines view in context
instead of adding onboarding pages.
Sources: [TipKit WWDC23](https://developer.apple.com/videos/play/wwdc2023/10229/),
[HIG onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding).

### Empty and error states
The apps that review well tell you what went wrong with this attempt, not a
generic list. HomeCourt users still complain that tracking fails with certain
lighting and angles ([fitgap summary](https://us.fitgap.com/products/039841/homecourt)),
so this is normal for CV apps; the difference is how specific the recovery
is. TrueLine's analyzer already knows where it failed (no lock, lost
mid-lane, too few points past the arrows). Surfacing that one reason, plus a
"Didn't count against your free throws" line (true per Settings copy), is a
small change with a big trust effect. Free-throw accounting is exactly the
moment users get suspicious.

### Haptics and accessibility
- Haptics: SwiftUI `.sensoryFeedback` is already used in calibration. Add it
  to record start/stop, analysis complete, and a distinct one for a pocket hit.
  Small effort, felt on every throw.
- Apple now shows **Accessibility Nutrition Labels** on the product page,
  declared in App Store Connect (VoiceOver, Larger Text, Sufficient Contrast,
  Reduced Motion, and others). A label should only be claimed if all common
  tasks work with that feature. TrueLine could honestly claim Reduced Motion
  and Dark Interface now, and Larger Text and VoiceOver after a pass. Few small
  apps have these filled in, so it stands out.
  Sources: [WWDC25 session 224](https://developer.apple.com/videos/play/wwdc2025/224),
  [label notes](https://tessl.io/registry/dpearson2699/swift-ios-skills/files/skills/ios-accessibility/references/nutrition-labels.md).
- The VoiceOver work that matters: metric tiles read as one element ("Entry
  board, 17.4, in target range"), the lane canvas gets a text summary ("Path
  crosses the arrows at board 12, breaks at board 7 at 42 feet, enters at
  17.4"), and Swift Charts get `accessibilityChartDescriptor` or labels.
  Calibration is visual by nature; it is fine to say so and not claim full
  VoiceOver for it. Apple's 2025 Inclusivity award went to Speechify
  ([9to5Mac](https://9to5mac.com/2025/06/03/apple-announces-2025-apple-design-award-winners/)),
  which shows Apple weights this.

### Widgets and Live Activities
- Arccos ships a Lock Screen Live Activity with yardage and club
  ([Arccos](https://arccosgolf.com/blogs/community/new-live-activity-feature)).
  That works because golf is played with the phone in a pocket. TrueLine's
  phone is on a tripod with the app in the foreground, so a Live Activity adds
  little. Apple's HIG frames Live Activities as tasks with a clear start and
  end, up to about 8 hours
  ([HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)).
  Skip.
- A small **Home Screen widget** (last session: throws, entry board mean and
  spread, pocket %) is cheap with WidgetKit and an App Group, looks good in a
  demo, but brings little to a once-or-twice-a-week practice user. Medium
  priority.

### Share sheets and share cards
Strava's lead here is the transparent "Sticker Stats" overlay that drops onto
an Instagram Story over your own photo
([BikeRadar](https://www.bikeradar.com/news/strava-sticker-stats-spring-2025-updates),
[Tom's Guide](https://www.tomsguide.com/wellness/fitness/stop-screenshotting-your-runs-this-hidden-strava-feature-looks-much-cleaner-on-instagram)).
TrueLine already has a share card, which many small apps lack. Two cheap
upgrades: a 9:16 Story size alongside 4:5, and a **session card** (all lines
fanned plus mean and spread), since consistency is what this audience cares
about. A short **video export with the path drawn on it** is what bowlers
actually post and what SwingVision offers (overlays in exported videos,
[App Store](https://apps.apple.com/us/app/swingvision-tennis-pickleball/id989461317)).
That one is medium to large (AVFoundation compositing) but very visible.

### Apple Watch
Arccos, Golfshot and SwingVision all have Watch apps
([Arccos Watch](https://arccosgolf.com/pages/apple-watch),
[SwingVision](https://apps.apple.com/us/app/swingvision-tennis-pickleball/id989461317)).
LaneTrax is iPhone-only
([App Store](https://apps.apple.com/app/id6475736816)). The one Watch feature
with real value for TrueLine is a **remote start/stop** so the bowler doesn't
walk back to the tripod each throw, plus the last throw's numbers on the
wrist. That needs WatchConnectivity and a camera session that can be driven
remotely. Large effort; defer until after 1.1 and the beta show whether the
walk-back is a real complaint.

### iCloud sync
See section 2. Short version: SwiftData can sync to the user's private
CloudKit database with no account and no backend. Medium effort because the
models need changes and the store is already shipped.

### Data export
"No way to export data or add notes" is already on the review-complaint list
in `next-steps-2026-11.md`. A per-session and all-history **CSV export** via
`ShareLink` with a `Transferable` file is small. Every metric is already a
`SavedShot` field. Add a JSON option if it is free. This also doubles as a
backup story until sync exists.

### Review prompts
Apple's `requestReview` shows at most 3 times in 365 days per user, and the
system may not show it at all, so it must not be on a button
([Apple docs](https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requestreview(in:))).
Usual practice is to ask after a clear success, at most once per version
([Atomic Object](https://spin.atomicobject.com/ios-review-prompt-customize/)).
For TrueLine: ask after the end of a session with 5 or more successful
throws, never after a tracking failure, never on the first session. With 2
ratings on 1.0, this is the cheapest thing on the list that changes how the
product page looks. A "Rate TrueLine" row in Settings can open the App Store
review page directly (`action=write-review`), which is allowed on a button.

### In-app feedback
Polished indie apps have a "Send Feedback" or "Report a problem" row that
opens Mail prefilled with app version, device model, iOS version, and (for a
failed throw) the analyzer's failure reason and fps. No backend and nothing is
collected by the app itself, since the user sends the email. Fits the privacy
story. Very small.

### What's New screen
Usually a one-time sheet on first launch after an update. For 1.1 it has a
real job: telling 1.0 users that old throws read several boards off and that
new throws are correct. That is honest, and it reads as a maintained product.
Pair it with an `analyzerVersion` field on `SavedShot` (already flagged as a
known issue) so old shots can show a small "measured with 1.0" note. Small.

### Restore purchases
Already done in Settings and the paywall. Apple reviewers expect a visible
restore control and reject apps that rely only on automatic restore
([vp0 guide](https://vp0.com/blogs/restore-purchases-button-missing-rejection-fix)).
One related bug from the Nov 1 handoff: Recalibrate on the review screen skips
the paywall check. Fix before 1.1 ships.

### Localization
Bowling has strong scenes in Japan and South Korea
([Korea Times](https://www.koreatimes.co.kr/opinion/20241117/rolling-through-time-a-history-of-bowling-in-korea),
[Bowling Heritage](https://bowlingheritage.com/tag/japan)), but board and
arrow vocabulary is specialized, and a bad translation hurts more than none.
Not worth it for v1. Worth doing once, cheaply: move strings into an Xcode
String Catalog so the app is localization-ready. Also confirm km/h is already
in Settings (it is). Interviewers sometimes ask about i18n; "string catalog
in place, units handled, translations deferred until demand" is a good answer.

### App Store product page
- App preview videos autoplay muted before the screenshots and you can have up
  to 3 per device size. The first 2 or 3 screenshots carry most of the weight
  ([Apple product page](https://developer.apple.com/app-store/product-page),
  [AppScreens](https://appscreens.com/blog/app-previews-vs-screenshots)).
  Most of the conversion-lift numbers quoted online are vendor claims; treat
  them as unverified.
- For TrueLine the strongest preview is 15 to 25 seconds of a real throw
  followed by the result reveal. That needs alley footage Adam owns, so do it
  right after the alley session.
- Product Page Optimization can A/B test up to 3 variants, and Custom Product
  Pages give separate URLs (useful for a "league bowlers" link vs a "coaches"
  link)
  ([AppleInsider](https://forums.appleinsider.com/discussion/225377),
  [Adapty](https://adapty.io/blog/markdown/custom-product-pages-app-store.md)).
  Low traffic means tests won't reach significance; one custom page for the
  Pitt and RMU club outreach is more useful than A/B tests.
- Fill in Accessibility Nutrition Labels (above) and keep the "Data Not
  Collected" label. Both show on the page.

## 2. Accounts

### What an account would enable
- Cross-device sync (iPhone to iPad, new phone).
- Coach sharing: a coach sees a bowler's sessions.
- A web dashboard like LaneTrax's.
- Server-side entitlement and email marketing.

### What it costs
- **A backend** to run and pay for (auth, database, storage for videos if
  shared). For a student this is ongoing work during exams and summers, and
  if it goes down, a paid one-time app stops doing something people paid for.
- **Privacy label change.** Apple defines "collect" as sending data off device
  where the developer can access it beyond servicing the request. Data handled
  only on device is not collected
  ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)).
  An account means at least User ID and probably Email Address, plus the shot
  data itself, all linked to identity. "Data Not Collected" goes away. That
  label is one of TrueLine's two stated advantages over LaneTrax, which
  requires account creation to get its free shots
  ([App Store](https://apps.apple.com/app/id6475736816)).
- **Guideline 5.1.1(v):** any app that supports account creation must let users
  start account deletion inside the app; a web link alone is not enough
  ([App Review help](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)).
  With Sign in with Apple you must also revoke the user's tokens through
  Apple's REST API on deletion
  ([Apple forums](https://developer.apple.com/forums/thread/707364)). More code,
  more to get rejected on.
- **Guideline 4.8:** if you add Google or other third-party login, you must
  also offer an equivalent privacy-focused option such as Sign in with Apple.
- **Maintenance:** password resets or SIWA edge cases, data deletion requests,
  a real privacy policy rewrite, possibly GDPR obligations.

### The no-account alternative
SwiftData can sync to CloudKit with one `ModelConfiguration` change plus the
iCloud and Remote Notifications capabilities. Data goes to the user's
**private** CloudKit database, which by default only the user can access and
which does not appear in the developer's CloudKit console
([CKContainer.privateCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)).
Apple's privacy page says developers are not responsible for disclosing data
collected by Apple services such as CloudKit, only data the developer collects
from them. Developers have asked Apple to confirm this case on the forums
without a clear official answer
([forum thread](https://developer.apple.com/forums/thread/710456)), but since
Adam can never read the data, "Data Not Collected" is the reasonable reading.
Many indie apps describe themselves this way ("no account, no server, data on
device and iCloud").

Model changes needed for CloudKit
([Apple](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices),
[Fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)):
- every attribute optional or with a default (`date` on both models has none);
- every relationship optional with an inverse (`BowlingSession.shots` is a
  non-optional array);
- no `.unique` attributes (none today) and no `.deny` delete rule (fine).
These touch a shipped store, so test the migration on a device with real 1.0
and 1.1 data before shipping. Sync metrics and paths only. Videos are large;
keep them local, or later sync them as files through iCloud Drive with a
toggle.

What CloudKit does not give you: coach sharing and a web dashboard. CloudKit
sharing (`CKShare`) can share records with another iCloud user later without
an account system, and a coach can already get a CSV export or share card.

### Recommendation
**Do not add accounts.** For a one-person, on-device, one-time-purchase app,
accounts cost the privacy label, add a deletion flow Apple checks, and create
a server Adam has to keep alive for people who paid once. None of the review
complaints in the competitor research ask for accounts. Instead:
1. CSV export now (covers "coach wants my data" and backup).
2. Optional iCloud sync through SwiftData + CloudKit in a later release,
   metrics only, with a Settings toggle.
3. Revisit accounts only if a paid coach tier becomes real, and then as a
   separate subscription product that pays for its own backend.

In interviews, "I chose not to build accounts, and here is why" is a stronger
story than a login screen.

## 3. Ranked additions for this app

Ranked by perceived quality per hour. Effort: S = an evening or two,
M = a few days, L = a week or more. "Recruiter" marks things someone
reviewing the app or repo would notice.

| # | Addition | Effort | Why | Recruiter |
|---|---|---|---|---|
| 1 | **Review prompt after a good session + Settings rate row + Mail feedback row with diagnostics** | S | 2 ratings is the most visible weakness on the product page. Feedback row catches bad experiences before they become 1-star reviews. | Yes, via rating count |
| 2 | **What's New sheet for 1.1 + `analyzerVersion` on shots** | S | Owns the 1.0 board offset honestly; marks old shots. Reads as a maintained product. | Yes, if asked "how do you handle bad releases" |
| 3 | **Specific tracking-failure reasons + "didn't use a free throw" + haptics on record/analysis/pocket** | S | Trust at the moments users are most likely to quit. Haptics are felt on every throw. | Somewhat, in a live demo |
| 4 | **CSV export per session and all history** | S | A named competitor complaint; also the coach-sharing and backup answer without accounts. | Yes |
| 5 | **Accessibility pass + declare Nutrition Labels** (VoiceOver summaries for tiles, lane canvas, charts; replace fixed font sizes; test at AX sizes) | M | Shows on the product page; few small apps do it. | Yes, strongly. Accessibility comes up in iOS interviews |
| 6 | **Product page refresh: app preview video from Adam's alley footage, reorder first 3 screenshots, one custom product page for club outreach** | M | First thing anyone sees. Blocked on the alley session. | Yes, strongly |
| 7 | **iCloud sync via SwiftData + CloudKit (metrics only, toggle)** | M | Removes "lose everything on a new phone" with no account and no label change. Needs careful migration testing. | Yes, as an architecture story |
| 8 | **Session share card in 9:16 + 4:5; later, video export with path overlay** | S for the card, L for video | Bowlers post video, not stats. The session card fits the consistency pitch. | Video export, yes |

Not recommended now: accounts, Live Activities, Apple Watch (revisit remote
start/stop after beta feedback), translations (do the String Catalog only),
Home Screen widget (nice demo, low user value; after 1 to 7).

Before any of this: fix the Recalibrate paywall bypass, and keep the alley
session as the gate. Polish does not help if the numbers are wrong, and Adam's
own Nov 1 note says accuracy is what would make him use it.
