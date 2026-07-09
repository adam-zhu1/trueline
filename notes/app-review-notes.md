# App Review notes — TrueLine

Draft of the material that goes into App Store Connect at submission time:
the **Notes** field under App Review Information, plus the reviewer test
script. Written so a reviewer with no access to a bowling lane can exercise
every flow (Guideline 2.1 — App Completeness — is the #1 rejection cause,
and this app's core feature needs an environment reviewers won't have).

## Paste into App Store Connect → App Review Information → Notes

> TrueLine analyzes a bowler's throw from a phone propped behind the bowling
> lane: it tracks the ball with an on-device ML model and reports speed,
> board at the arrows, breakpoint, launch/entry angle, and pocket entry.
>
> Testing without a bowling lane:
>
> 1. The full analysis pipeline can be exercised with the sample video at
>    [SAMPLE VIDEO LINK — record at field test, own footage only]. Save it
>    to Photos, then on the Bowl tab choose "Analyze Existing Video", pick
>    it, tap "Use Throw", confirm the proposed lane corners ("Looks Good"),
>    and the shot's metrics and tracked path appear in a few seconds.
> 2. "Start Session" opens the camera. Recording anything that isn't a
>    bowling throw ends at an explanatory "Couldn't track the ball" screen
>    with recovery options — this is expected behavior, not an error state.
> 3. If camera permission is denied the record screen explains and deep
>    links to Settings.
>
> There are no accounts and no server: all processing is on-device, the app
> makes zero network requests, and the privacy label is "Data Not
> Collected". No demo credentials are needed.

## Reviewer-perspective test script (run before every submission)

Simulates a reviewer with no lane. All paths must end in an explanation or
a way out — never a dead end, hang, or crash.

| # | Flow | Expected |
|---|------|----------|
| 1 | Cold start | Launch animation (tap skips) → onboarding (first run) → home |
| 2 | Start Session → deny camera | Explanation + "Open Settings" deep link; X exits |
| 3 | Start Session, no camera hardware (Simulator) | "Camera unavailable" message; X exits |
| 4 | Record 3 s of an office wall → Use Throw | Calibrate shows draggable default corners (auto-detect finds no lane) → analysis → "Couldn't track the ball" with Adjust Corners / Discard |
| 5 | Analyze Existing Video → cancel picker | Home unchanged |
| 6 | Import an iCloud-only/unloadable video | "Couldn't load that video" alert |
| 7 | Import a long non-bowling video → start analysis | X on the progress screen backs out to review; no hang |
| 8 | Import → Pick Another on review | Returns home to re-pick |
| 9 | Calibrate → Back / Reset / degenerate corners | All recoverable; Looks Good disabled only while the frame loads |
| 10 | History with nothing saved | "No shots yet" empty state |
| 11 | Settings → toggle videos off, delete all videos (none) | Delete disabled at zero; footer explains metrics are kept |
| 12 | Reduce Motion on | Static launch wordmark, no animation |
| 13 | Kill the app mid-analysis, relaunch | Clean launch; orphan sweep clears any leftover replay file |

## Submission-time checklist

- [ ] Replace the sample-video placeholder with a link to Adam's own
      behind-approach recording (from the field test — NOT the Instagram
      test clips; we don't hold rights to those).
- [ ] Verify the sample video produces good metrics in a clean install.
- [ ] Privacy label: Data Not Collected. `PrivacyInfo.xcprivacy` ships
      (UserDefaults / CA92.1 only); `ITSAppUsesNonExemptEncryption = NO`.
- [ ] Support URL + privacy policy live (task #18) before submitting.
- [ ] Don't name Specto or USBC anywhere in metadata.
