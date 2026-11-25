# Submission day, TrueLine 1.1

One page, in order. Text to paste lives in `app-store-listing.md` ("1.1
submission") and `app-review-notes.md`. Steps checked against Apple's App
Store Connect help on Nov 15, 2026 (links at the bottom).

## Before you start

- [ ] Alley session done, and the clips you'll link are your own footage.
- [ ] `[SAMPLE VIDEO LINK]` and `[SCREEN RECORDING LINK]` filled in
      `app-review-notes.md`. Both open in a private browser window with no
      login. Notes field recounted (4,000 max).
- [ ] Reviewer test script in `app-review-notes.md` run on a clean install of
      the Release build, including the device-only rows (13, 14, 16, 17, 23).
- [ ] Accessibility device check done for Larger Text and the Light
      appearance (`app-store-listing.md`, Accessibility Nutrition Labels).
- [ ] On `main` with every queued commit published (`~/.cache/trueline-publish/queue.txt` empty, or archive from the local work branch), working tree clean. Version 1.1, build 3
      (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`). If build 3 was ever
      uploaded before, bump the build number. App Store Connect rejects a
      repeated build number for the same version.

## 1. Upload the build (Xcode)

1. Scheme Trueline, destination "Any iOS Device (arm64)".
2. Product > Archive. The Organizer opens when it finishes.
3. Select the archive, then Distribute App > App Store Connect > Distribute
   (Upload). Keep automatic signing and symbol upload on.
4. Wait for Apple's "has completed processing" email. The build then shows in
   the TestFlight tab. `ITSAppUsesNonExemptEncryption = NO` is in the
   Info.plist, so there is no export compliance question.

## 2. Create version 1.1 (App Store Connect)

1. Apps > TrueLine > the + next to iOS App in the sidebar > enter `1.1` >
   Create. 1.0's metadata copies over.
2. **What's New in This Version:** paste from the listing file.
3. **Description** and **Keywords:** paste. Keywords are 97 characters,
   commas and no spaces.
4. **Promotional text:** leave the 1.0 text for now. The new text says 25
   free throws, which is false until 1.1 is live. Change it on release day
   (step 6). It doesn't need review.
5. **Support URL** https://truelinebowling.com/support/ and **Marketing
   URL** https://truelinebowling.com/ on the version page.
6. **Screenshots** under the iPhone media: the "iPhone with Dynamic Island
   (medium display)" size, 1206 x 2622, is the one Apple marks as required.
   Upload the 1320 x 2868 set to the large display size too. Up to 10 each,
   no prices or free-throw counts in captions (2.3.7).
7. **Build:** in the Build section, pick build 3.
8. Save.

## 3. App-level fields (sidebar, outside the version page)

1. **App Information:** subtitle "Speed and entry angle per shot". Name
   unchanged. It goes live with the version. Check that the Age Rating shows
   no unanswered questions. Apple added new age rating questions in 2025 and
   unanswered ones block update submissions.
2. **App Privacy:** stays Data Not Collected. Privacy Policy URL is
   https://truelinebowling.com/privacy/. Change nothing; just confirm no
   "needs attention" banner.
3. **In-App Purchases:** TrueLine Unlimited stays Approved. Don't add it to
   the submission.
4. **App Accessibility:** do **not** publish yet. Apple publishes these
   labels immediately, separately from review, and only for a device with a
   live version. Published now, they would describe 1.0, which lacks the 1.1
   VoiceOver and Larger Text work. Do it after release (step 6).

## 4. App Review Information and release options (version page)

1. **Sign-in required:** off. **Contact:** Adam, phone, and
   support@truelinebowling.com.
2. **Notes:** paste the block from `app-review-notes.md`. Attach the screen
   recording if the attachment field takes it.
3. **App Store Version Release:** "Manually release this version". This lets
   the site, the promo text and the tester note all go out on the same day.
4. **Phased Release for Automatic Updates:** select "Release update over a
   7-day period using phased release". Recommended. It costs nothing,
   anyone can still download 1.1 by hand on day 1, and if a crash shows up
   you can pause for up to 30 days in total. Days 1 to 7 go to 1%, 2%, 5%,
   10%, 20%, 50% and 100% of auto-update users. With few 1.0 users, the
   main benefit is the pause option.
5. Save.

## 5. Submit

1. Top right: **Add for Review**, then create a new submission. Status
   becomes Ready for Review. Nothing is sent yet.
2. Open the draft submission (Draft Submissions, bottom right, or App Review
   in the sidebar) and check that it holds version 1.1 only.
3. **Submit for Review.** Status goes to Waiting for Review, then In Review.
4. Write the date and time in the "Submission log, 1.1" in
   `app-review-notes.md`.

If Apple asks for information (2.1): reply in the Resolution Center with the
attachments. If the version then stays Rejected, edit the version's Notes
field so "Update Review" becomes clickable. That is what worked for 1.0 on
Aug 19.

## 6. After approval (status Pending Developer Release)

1. Click **Release This Version**. The phased release starts at day 1.
2. **Promotional text:** paste the 1.1 text (25 free throws).
3. **App Accessibility:** Get Started > confirm iPhone > Add iPhone Support >
   Yes > select Dark Interface, Reduced Motion, Sufficient Contrast, and
   Larger Text only if the device check passed > Next > Publish. It may take
   up to 24 hours to show.
4. **Website.** In `~/Projects/truelinebowling-site`: as of Nov 15 there is
   `main` is the live 1.0 site and the 1.1 version sits on the `release-1.1`
   branch (25 free throws, launch speed label, new FAQ), committed but not
   deployed. Merge it: `git checkout main && git merge --ff-only release-1.1`. Then run
   `tools/deploy.sh`, which builds from the checked-out HEAD. Check
   https://truelinebowling.com shows 25 free throws and that
   https://truelinebowling.com/support/ and /privacy/ load. Until 1.1 is
   live, **don't run deploy.sh from main**, since it would advertise 25 free
   throws to 1.0 users.
5. **Git** (in this repo, after the App Store page shows 1.1):

   `main` already carries the 1.1 work (merged Nov 15, 1.0 is tagged
   `v1.0`). Tag the commit the build was archived from:

   ```
   git tag -a v1.1.0 <archived commit> -m "TrueLine 1.1 (build 3), released <date>"
   git push origin v1.1.0
   ```

   Commit as Adam, no AI trailers. Push only when you want it public.
6. Send the "1.1 is live" note and offer codes to TestFlight testers
   (`beta-outreach.md`). Ask for an honest rating once, with nothing attached.
7. Watch the crash reports in Xcode Organizer for the first 3 days. If
   something bad shows up: Pause Phased Release, fix, ship 1.1.1.
8. After 30 days: App Analytics search terms, then swap weak keywords.

## Sources

- [Create a new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app) ("Add for Review", draft submission, "Submit for Review")
- [Release a version update in phases](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) (medium Dynamic Island size required)
- [Manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels) (live version needed, publishes immediately)
- [Updated age ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf)
