# App Review notes, TrueLine 1.1

What goes into App Store Connect for the 1.1 submission: the Notes field under
App Review Information, the attachments, and the test script we run as a
reviewer would before submitting. Guideline 2.3.1 requires new features to be
described with specificity in the review notes, and 1.0 was held once under
2.1 until Apple got a screen recording, so 1.1 goes in with both up front.

Build: version 1.1 (build 3), iPhone only. Listing text is in
`app-store-listing.md`, section "1.1 submission".

## The two links (filled Nov 22)

- Sample video: https://truelinebowling.com/review/trueline-sample-throw.mov,
  Adam's own IMG_5108 strike clip (data/test_videos/alley-2026-08-17), served
  from the live site as a download, noindex. Never the Instagram test clips,
  which we don't hold rights to.
- Screen recording: https://truelinebowling.com/review/trueline-1.1-recording.mp4.
  Recorded at home on the iPhone (no alley visit before 1.1), importing the
  sample video. Publish it with `output/release-1.1/publish-review-recording.sh [file]`,
  which puts it on the site and checks the link. Shot list in
  `output/release-1.1/MORNING.md`. The drift check needs a live lane, so the
  recording shows a second throw reusing the calibration instead, and the
  Notes say so.

Also upload the screen recording as an attachment in App Review Information if
the field accepts it, so the reviewer doesn't depend on the link.

## Paste into App Store Connect > App Review Information > Notes

3,938 characters with both links filled in (limit 4,000). Counted Nov 22.

```
TrueLine measures a bowling throw from an iPhone set behind the approach. An on-device model tracks the ball, and the app reports launch speed, board at the arrows, breakpoint, entry board and entry angle. There is no account and no server of ours. Analysis runs on the iPhone and the privacy label is Data Not Collected. No login is needed.

ATTACHMENTS
Sample video (our own footage, a strike from behind the approach): https://truelinebowling.com/review/trueline-sample-throw.mov
Screen recording of 1.1 on an iPhone, using the sample video: https://truelinebowling.com/review/trueline-1.1-recording.mp4

TESTING WITHOUT A BOWLING LANE
1. Save the sample video to Photos on the test iPhone.
2. On the Bowl tab, tap Analyze Existing Video and choose the sample video. Tap Use Throw.
3. Calibrate by placing six points on the frame (touch, slide, lift; pinch or double-tap to zoom). The header names each spot in turn: both ends of the foul line, three arrows, then the head pin. A lane outline appears after the sixth tap. Drag its far corners until the drawn rings sit on the pins, then tap Looks Good.
4. After a few seconds the result screen shows the tracked path on the video and the metric tiles.
A video that is not a bowling throw ends at a screen that explains why the ball could not be tracked. That is expected.

NEW IN 1.1
- Calibration is six guided points on lane markings instead of dragging four corners. The frame zooms (pinch, two-finger pan, double-tap) and a magnifier shows where each point lands.
- Drift check: on the second and later throws of a recorded session, the throw's first frame is compared with the calibration frame. A small shift is corrected and the review screen says the lane was re-aligned. A large one (over 8 boards at the pins, or a poor match) asks the bowler to recalibrate. It needs a live session at a lane and does not run on imported videos, so it cannot be shown with the sample video. The screen recording shows a second throw reusing the calibration.
- Zoom: 1x and 2x buttons on the record screen. Hidden while recording. Changing zoom mid-session asks for a new calibration.
- Measurement fix: 1.0 placed the ball several boards to one side. Shots saved with 1.0 show a "1.0 tracker" tag in History and a note on the shot saying the numbers can be a few boards off.
- What's New sheet: shown once to people updating from 1.0 (finished onboarding or saved a throw). Fresh installs never see it, so a clean review install won't show it.
- 25 free throws, up from 10. Only a successful analysis uses one.
- Failure reasons: a throw that can't be tracked shows the cause (ball not found, lane outline doesn't match, ball lost too early, or video unreadable), the matching fix as the main button, and a note that no free throw was used.
- CSV export: Export All as CSV in History, Export CSV in each session. One row per throw.
- Settings > Send Feedback opens a Mail draft to support@truelinebowling.com with the app version and iPhone model filled in. Nothing from the user's throws is included.
- Settings > Rate TrueLine opens the App Store review page. The system rating prompt can appear after the third successful analysis, on Home, never during a throw.
- Accessibility: VoiceOver labels for metrics, the lane drawing, stats and history. Text scales with Larger Text.
- Paywall: the price comes from StoreKit, with a spinner while it loads, or Try Again and no price if the App Store doesn't respond.
- Ball tracking reaches farther down the lane, including in 60 fps video. Speed is labeled launch speed. Left-handed throws draw on the left of the lane. Settings has a Light appearance.

IN-APP PURCHASE
TrueLine Unlimited (com.adamzhu.Trueline.unlimited) is a non-consumable that unlocks unlimited analyses. There is no subscription. To test it without using the free throws, open Settings and tap Unlock TrueLine Unlimited. Restore Purchases is in Settings and on the paywall.
```

## What each 1.1 change is, for our own reference

Details behind the Notes bullets, checked against the v1.1 source on Nov 15.

| Change | Where in the app | How a reviewer can see it | Source |
|---|---|---|---|
| Six-tap calibration | Calibrate screen after Use Throw | Sample video, step 3 | `LandmarkFit.targets`, `CalibrationView` |
| Drift check | Review screen of throw 2+ in a recorded session | Screen recording only. Imported clips don't set a drift reference | `DriftCheck` (`maxDeckBoards = 8`), `CaptureFlowView` |
| 1x/2x zoom | Record screen, lens chips | Any device with a camera. Zoom change mid-session forces recalibration | `CameraModel.zoomOptions`, `RecordView.ZoomPicker` |
| Board fix and older-shot marking | History rows ("older version"), shot screen note | Only on a device upgraded from 1.0 with saved shots | `SavedShot` analyzer version, `ShotResultContent` |
| What's New sheet | Full screen on first launch after the update | Only on an upgrade from 1.0. Fresh install never shows it | `WhatsNew.shouldShow` |
| 25 free throws | Results ("N of 25 free throws left"), Settings, paywall | Any install | `TruelineStore.freeThrowLimit` |
| Failure reasons, no throw used | Tracking-failed screen | Import or record a non-bowling video | `TrackingFailure`, `TrackingFailedView` |
| CSV export | History toolbar "Export All as CSV", session "Export CSV" | After one successful analysis | `ShotCSV` |
| Send Feedback | Settings | Opens Mail. With no mail account iOS shows its own prompt | `AppInfo.feedbackMailURL` |
| Rate TrueLine | Settings link, plus system prompt after 3 good results | Link always. Prompt is up to iOS and won't show in every case | `ReviewPrompt`, `ContentView` |
| Accessibility | Throughout | VoiceOver, Larger Text | `notes/accessibility.md` |
| Paywall spinner / Try Again | Paywall button | Airplane mode, then open the paywall | `PaywallView` |
| Tracking range | Analysis | Sample video tracks to the pins | lane-box detection, far-lane crop, wall-clock tracker |

The CSV columns are date, session, speed_mph, board_at_arrows,
breakpoint_board, breakpoint_ft, entry_board, entry_angle_deg and
analyzer_version, so 1.0 rows (analyzer version 1) can be filtered out.

## Reviewer-perspective test script (run before every submission)

Simulates a reviewer with no lane, on a clean install of the release build.
Every path must end in an explanation or a way out, never a dead end, hang
or crash.

| # | Flow | Expected |
|---|------|----------|
| 1 | Cold start | Launch animation (tap skips), onboarding on first run, then Home. No What's New sheet |
| 2 | Start Session, deny camera | Explanation and "Open Settings" deep link; X exits |
| 3 | Start Session, no camera hardware (Simulator) | "Camera unavailable" message; X exits |
| 4 | Record 3 s of a wall, Use Throw | Six-tap calibration. After any taps and Looks Good: a tracking-failed screen naming the cause, the matching button first, "This throw didn't use one of your free throws.", Discard |
| 5 | Analyze Existing Video, cancel picker | Home unchanged |
| 6 | Import an iCloud-only or unloadable video | "Couldn't load that video" alert |
| 7 | Import a long non-bowling video, start analysis | X on the progress screen backs out to review; no hang |
| 8 | Import, Pick Another on review | Picker reopens; cancelling it lands on Home |
| 9 | Calibrate: Back, Undo, Reset, colinear taps | All recoverable. Bad taps say "Those taps don't line up with a lane." |
| 10 | Import the sample video and calibrate | Result with path and tiles; free throws drop from 25 to 24 |
| 11 | History with nothing saved | "No shots yet" empty state |
| 12 | History > Export All as CSV, session > Export CSV | Share sheet with a .csv; opens in Numbers with one row per throw |
| 13 | Settings > Send Feedback | Mail draft to support@truelinebowling.com with version and model |
| 14 | Settings > Rate TrueLine | App Store write-a-review page |
| 15 | Airplane mode, Settings > Unlock TrueLine Unlimited | Spinner, then Try Again with "Couldn't reach the App Store" note. No price shown |
| 16 | Online, Unlock, cancel the payment sheet | Back to the paywall, nothing changed |
| 17 | Sandbox purchase, delete app, reinstall, Restore Purchases | Settings shows "TrueLine Unlimited: Unlocked" |
| 18 | Record screen 1x/2x chips | Selection sticks across sessions; chips hidden while recording |
| 19 | Settings > toggle videos off, delete all videos | Delete disabled at zero; footer says metrics are kept |
| 20 | Reduce Motion on | Static launch wordmark, onboarding hand doesn't flip |
| 21 | Largest accessibility text size | Onboarding and paywall scroll; buttons wrap, nothing clipped |
| 22 | Kill the app mid-analysis, relaunch | Clean launch; leftover replay file cleared |
| 23 | Upgrade test: install 1.0 from the App Store, save a throw, update to the 1.1 build | What's New sheet once; older throws tagged "older version"; sheet doesn't return on next launch |

Rows 13, 14, 16, 17 and 23 need a real device. Run 23 through TestFlight
over the App Store 1.0 install so the saved data carries across.

### Sim run, Aug 15 2026 (automated, iPhone 17 Pro Max sim)

Passed: 1, 2, 3, 5, 7, 8, 9 (drag recovery), 10, 11, 12, 13. The full
import → calibrate → analyze → result pipeline ran end to end on the June
regression clip, path overlay drawn on the video, discard cleanup verified.

Not runnable in sim, do on device before submitting: 4 (record a real wall
clip), 6 (iCloud-only import), and a manual check that calibration's Reset
button restores corners (automated click was inconclusive).

Findings, resolved Aug 15:
- Quota: a partial result (entry board "--") consumes a free throw and
  Discard does not refund. DECIDED (Adam): keep as-is — analyzed = consumed.
- Calibration proposal-clobbers-drag: RETRACTED. CalibrationView already
  guards this (`userAdjusted` flag); the automated drag had missed the
  window. Reset restores the proposal by design, so a no-op when corners
  equal the proposal is correct. Remaining: one 30-second feel-check of
  Reset on device.


## Submission-time checklist for 1.1

- [ ] Fill `[SAMPLE VIDEO LINK]` and `[SCREEN RECORDING LINK]`; recount the
      Notes field (4,000 limit).
- [ ] Verify the sample video gives a clean result on a clean install of the
      release build, following the Notes steps word for word.
- [ ] Release build only: no `-bankFreeThrows` or `-fieldFootageMode` launch
      args in the recording, and the free throw count reads "of 25".
- [ ] Privacy label stays Data Not Collected. `PrivacyInfo.xcprivacy` ships
      (UserDefaults / CA92.1 only); `ITSAppUsesNonExemptEncryption = NO`.
- [ ] Support and privacy pages live at truelinebowling.com, and the old
      adamzhu.dev and github.io forms still resolve for 1.0 installs (since
      Nov 23 adamzhu.dev/trueline/, /support and /privacy redirect to
      truelinebowling.com). The 1.1 app links truelinebowling.com only.
- [ ] Listing fields from `app-store-listing.md` "1.1 submission", including the
      new subtitle, keywords and the Accessibility Nutrition Labels.
- [ ] Screenshots match 1.1 (2.3.3); upload the 1206 x 2622 set too.
- [ ] No Specto, USBC or PBA in any metadata.
- [ ] The IAP needs no change; confirm it still shows Approved and the review
      screenshot is current.

## Submission log, 1.1

- Build 3 archived Nov 22 (output/release-1.1/TrueLine-1.1-b3.xcarchive). Upload blocked: "PLA Update available", Adam must accept the updated Program License Agreement at developer.apple.com first. Target: submit week of Nov 22, without an alley visit.

## Submission log, 1.0


- **1.0 (build 2) submitted Aug 16, 2026 ~12:53 AM** together with the
  TrueLine Unlimited IAP. Deliberately submitted before the alley visit:
  review notes offer a sample video on request instead of linking one.
  If Guideline 2.1 comes back, reply in Resolution Center with the alley
  clip and resubmit — that video gets recorded Monday regardless.
- Build 2 is iPhone-only (build 1 accidentally declared iPad and ASC
  demanded iPad screenshots). Manual release selected, so approval does
  not auto-publish.

- **Aug 16, 10:55 PM — rejected 2.1 "Information Needed"** (the expected,
  mild outcome; the IAP itself shows Ready for Review, i.e. accepted).
  Apple wants an on-device screen recording of the core flow (launch,
  camera prompt, a real analysis, the purchase sheet) plus an 8-point
  questionnaire. Reply drafted at output/review-reply-draft.md; recording
  to be captured at the Aug 17 alley visit on a clean release install,
  then Reply + Resubmit (same build 2, no new binary).
- **Aug 18 — alley visit done** (Perfect Games, lane 14, iPhone 16 Pro,
  iOS 26.5.2, build 2 confirmed on device). Main screen recording covers
  onboarding, camera prompt, a real analyzed throw, save, History/Stats,
  and the paywall screen — but ends before the App Store payment sheet
  appears, so a short supplemental recording of Settings -> Unlock ->
  payment sheet -> cancel gets captured at home and attached alongside
  (reply draft item 1 updated to describe two recordings). Two blemishes
  understood, neither blocking: the visible "99 of 10 free throws left"
  is leftover `-bankFreeThrows` field-test state (TruelineStore reads the
  launch arg in release; fix by relaunching with a realistic bank before
  the supplemental clip), and the wrong-looking ball line traces to
  calibration corner placement — the bottom-left corner was dropped on
  the approach past the foul line, skewing the homography near launch
  while leaving speed plausible. Re-import with careful corners before
  trusting the strike clip's metrics.
- **Aug 18 harness cross-check:** the strike clip (IMG_5108) through the
  Mac pipeline with a carefully hand-placed calibration gives entry
  ~board 14-15 — pocket side, matching the on-camera strike within a few
  boards. Pipeline geometry is sound; the app's Brooklyn-looking line for
  the same clip came from user calibration. Prime suspect is the top
  corners landing on a NEIGHBOR's pin deck: with the camera left of the
  lane, the lane's own deck sits far right in frame and the deck that
  looks centered belongs to the next lane over. Supplemental
  purchase-sheet recording captured and verified sufficient (sheet with
  price shown; sign-in only after Pay). v1.1 backlog: calibration
  wrong-deck guidance + mid-session drift check + record-screen zoom.
- **Aug 19, 5:24 PM — RESUBMITTED, "Waiting for Review"** (both items:
  app version + IAP). The path that worked: reply alone left the version
  "Rejected" with the submission-level Resubmit greyed out; editing the
  version's Notes field (now pointing reviewers at the Aug 19 reply's
  attachments) enabled the version page's "Update Review" button, which
  flipped the whole submission back into the queue. Next signal: Apple's
  status emails (In Review → verdict).
- **Aug 19, ~2:02 AM — replied in Resolution Center** with the 8 answers
  and three attachments (alley core-flow recording, purchase-sheet
  recording, IMG_5108 strike clip), sent from the phone via remote
  control. "Resubmit to App Review" stays greyed out by design — no item
  was edited; for an information-needed rejection the reply itself
  returns the submission to the reviewer. Ball is with Apple; watch
  email. Correction to the Aug 18 diagnosis: pin-deck choice was right
  (pinfall-verified, lane 15); the wrong-looking lines come from far-end
  corner precision — the deck is ~90 px wide in 1x footage, ~2.3 px per
  board, so ~10 px of corner slop moves entry readings 4+ boards. This
  promotes record-at-2x zoom to the top of the v1.1 accuracy list.
