# TrueLine 1.1 launch plan

*Researched Nov 3, 2026. This builds on `app-store-listing.md`, `next-steps-2026-11.md`,
`research-bowling-workflows.md` and `polish-research.md` (stage) and does not repeat them.*

## The short version

1. Ship 1.1 before about Dec 12. Apple's review queue slows in the second half of
   December. Then run a TestFlight round with local college bowlers over the
   break, and do the public push in January and February.
2. Change the subtitle to **Speed, entry angle, breakpoint** and use the keyword
   field below. Real App Store autocomplete shows that bowlers type "tracker",
   "trainer", "coach", "stats", "speed meter" and "rev rate". Nobody types
   "entry angle" into the search bar.
3. The App Store is filling up with phone ball trackers, many released in 2026
   (list below). Two of them are free and also show "Data Not Collected". So
   "on device, no account" is no longer unusual. Lead with the result screen on
   real footage and with the one-time price, and get rev rate out fast.
   "bowling rev rate" is a real search with weak results.
4. Get ratings from people who actually used the app: the prompt already on
   `stage`, TestFlight testers asked once when 1.1 is live, and pro shops. Never
   tie a code or a reward to a review.
5. The biggest App Review risks are a repeat 2.1 "information needed" (so attach
   the sample video and a screen recording up front) and not describing the new
   features in the Review Notes, which guideline 2.3.1 requires.

## 1. Product page

### Screenshot sizes in 2026

Apple's spec page now says the one **required** iPhone size is "iPhone with
Dynamic Island (medium display)" (iPhone 17, 17 Pro, 16 Pro and similar: 1206 x 2622
or 1179 x 2556). The 6.9 inch group (1320 x 2868) has no stated requirement.
If a size group is missing, Apple uses scaled screenshots from the next size up,
and that is how 1.0 passed with only 6.9 inch images. Up to 10 screenshots per
size, in PNG or JPEG.
[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)

**Do this:** capture the 1.1 set twice from the simulator, once on the iPhone 17 Pro Max
(1320 x 2868) and once on the iPhone 17 Pro (1206 x 2622). It costs ten minutes
and removes any doubt. The app is iPhone only, so no iPad set is needed.
Starting April 2027, a new "iPhone Duo" size becomes required for apps built
with the iOS 27.1 SDK. That will matter for 1.2, not for 1.1.

### How many, what order, what captions

- Use **7 or 8**. The first three show up in search results, so they decide most
  taps. The rest are for people already on the page.
- Guideline 2.3.3 says screenshots must show the app in use. Real UI with a text
  caption above it is fine. Do not use title art or a splash screen.
  [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Several ASO vendors reported in June 2025 that Apple started reading the
  caption text in screenshots for search. Apple has not confirmed this. So put
  the words people search for into the captions, but don't count on it.
  [AppScreenshotStudio summary](https://appscreenshotstudio.com/blog/how-apple-ocr-indexes-app-store-screenshot-text-2026),
  [Appdrift](https://appdrift.co/blog/app-store-screenshot-text-indexing)
- Guideline 2.3.7 says screenshots and previews should not include prices. Keep
  "$14.99", "free" and "25 free throws" out of the captions and put them in the
  description and promotional text. "One-time purchase" or "no subscription" in a
  caption is a gray area. Skip them in the screenshots too.

Order to aim for, once the alley session gives clean clips:

| # | Screen | Caption idea |
|---|---|---|
| 1 | Shot result on **real lane footage**, path drawn on it, metric tiles visible | Ball speed and entry angle on every throw |
| 2 | Session lines (all throws fanned) with mean and spread | See how consistent your line really is |
| 3 | Record screen over a real lane, phone behind the approach | One iPhone behind the approach. No sensors. |
| 4 | Lane view: arrows board, breakpoint board and distance | Arrows, breakpoint and entry board |
| 5 | Trends / stats dashboard | Track speed and pocket % across sessions |
| 6 | Arsenal compare | Compare how each ball reacts |
| 7 | Drift check or calibration overlay on real footage | Bumped the tripod? TrueLine notices. |
| 8 | Privacy / export | No account. Your throws stay on your iPhone. Export to CSV. |

Real footage against mockups: use the real app on real footage for 1 and 3.
Every competitor's top screenshot is a lane with a line on it. A seeded demo lane
drawing looks like a mockup next to them. Device frames are optional. A plain
dark background with mint captions matches the brand and is quicker to make.

### Preview video

Apple's rules ([App Preview specs](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications),
[Apple's preview guidance](https://developer.apple.com/app-store/app-previews/)):

- 15 to 30 seconds, up to 3 per size, 30 fps max, 886 x 1920 portrait for the
  6.9 inch group. It autoplays muted before the screenshots.
- **It may only show footage from inside the app.** Apple says not to film
  people using the device and not to use over-the-shoulder shots (guideline
  2.3.4). This matters for TrueLine: you **cannot** cut in a separate camera
  angle of you bowling. Real lane footage is fine when it appears inside the app,
  through the record screen, the replay or the path overlay. That covers
  everything you would want to show anyway.
- If you show features that need the in-app purchase, you must say so, in the
  footage or on the end frame. Example: "Unlimited throws with a one-time
  unlock". Leave the price out.
- Pick a strong poster frame, the result screen with the path drawn. Some people
  only ever see that one frame.
- Vendor blogs put typical watch time at 4 to 6 seconds, so the first 3 seconds
  have to do all the work. These numbers are unverified vendor claims.
  [AppFollow](https://www.appfollow.io/blog/app-store-video-strategy/),
  [SplitMetrics](https://splitmetrics.com/blog/create-app-preview-video-app-store-ios/)

Storyboard, about 20 seconds:

- 0 to 3 s: the replay of a real throw with the path drawing itself to the pins,
  then the tiles land. Caption: "Your entry angle, on every throw".
- 3 to 8 s: the record screen at the lane, then a throw, then stop. Caption:
  "Prop your iPhone behind the approach".
- 8 to 14 s: session lines fanning in, then the spread numbers. Caption:
  "See how repeatable your shot is".
- 14 to 18 s: trends and arsenal, quick cuts.
- 18 to 20 s: end frame with the wordmark and "Unlimited throws with a one-time
  unlock".

On a student budget:

1. At the alley, run the app on the tripod phone and turn on Control Center
   screen recording before each throw. Record 15 to 20 throws, so a few come out
   clean.
2. Record the result and history screens at home from the same saved shots, or
   on the simulator with `xcrun simctl io booted recordVideo` and
   `simctl status_bar override` for a clean status bar.
3. Edit in iMovie or DaVinci Resolve (free). Use dissolves and fades only. Apple
   warns against transitions that suggest features the app doesn't have. Skip
   music unless you own it. Use UI sound or silence.
4. Export, then make the file match Apple's specs with ffmpeg, adding a silent
   stereo track because previews without audio are a common upload failure:
   `ffmpeg -i edit.mov -f lavfi -i anullsrc=r=48000:cl=stereo -shortest -vf "scale=886:1920,fps=30" -c:v libx264 -profile:v high -level 4.0 -b:v 11M -pix_fmt yuv420p -c:a aac -b:a 256k preview.mp4`
5. Don't put dates or "new" in the captions. Apple says these make a preview
   look dated.

Tell people this before the alley visit: Apple says you may show only material
you have the right to show. Get the center's OK to film, and keep other bowlers'
faces out of the frame. The tripod view from behind the approach mostly does
this already.

### Custom product pages and in-app events

- **Custom product pages:** these are worth one or two at this scale, but not for
  A/B testing. Since Oct 2025 you can have 70, and you can **assign keywords** to
  each one, so that page shows up in search for those words instead of the
  default page. The keywords come from your existing keyword field. They do not
  add new ones. [Apple news, Oct 29 2025](https://developer.apple.com/news/?id=gf6mgrs6),
  [Phiture](https://phiture.com/blog/keyword-based-custom-product-pages-cpps-arrive-in-app-store-connect/)
  Two useful ones:
  - A **speed** page for the "meter", "speed" and "trainer" searchers. Put the
    speed tile and speed trend screenshots first.
  - A **club / coach** page whose link goes into the college and pro shop
    outreach. Put the session consistency and CSV export screenshots first. Its
    own URL also shows you in App Analytics which outreach brought downloads.
- **In-app events:** skip them for 1.1. An event has to be a real, time-limited
  thing inside the app ("Challenge", "Competition" and similar types). TrueLine
  doesn't have one. A later "two-week spare drill challenge" using target-line
  practice could qualify. Events can be submitted without a new app version.
  [Apple in-app events](https://developer.apple.com/app-store/in-app-events/)

## 2. ASO

### What bowlers actually search for (evidence)

Real App Store autocomplete, US storefront, pulled Nov 3 2026 from Apple's search
hints endpoint:

| Typed | Suggestions that matter |
|---|---|
| bowling t | **bowling tracker**, free bowling tracker, **bowling trainer** |
| bowling s | bowling score keeper, bowling stats, **bowling speed meter**, cricket bowling speed |
| bowling sp | **bowling speed meter**, bowling speed, cricket bowling speed |
| bowling r / re | **bowling rev rate** (the only suggestion) |
| bowling a / an | bowling app, bowling average, bowltrace: bowling analysis |
| bowling c / co | bowling calculator, **striker: bowling coach**, strike zone bowling coach |
| bowling b | bowling ball arsenal, bowwwl bowling ball database |
| bowling l | bowling league |
| tenpin / ten pin | tenpin toolkit, ten pin toolkit |
| specto, lanet | specto bowling, lanetrax, lanetalk |
| entry angle, bowling ai, bowling vi | nothing |

What this tells you:

- "Tracker" is the main search, but most results for it are **score keepers**
  (Bosc, Bowlski, StrikeMaster, PinPal, Bowling Score Keeper Log). The name
  already ranks TrueLine for it (it shows up 6th for "bowling ball tracker" and
  11th for "bowling tracker" in Apple's search API). The screenshots have to make
  clear in one glance that TrueLine tracks the **ball**, not the score.
- "Bowling speed" is crowded by **cricket** apps ("cricket bowling speed", Speed
  Gun For Cricket). Any speed keyword brings in some cricket traffic. "Tenpin"
  and "lane" help Apple file TrueLine under ten-pin bowling.
- "PBA" in autocomplete leads to "pba bowling challenge", a game. That traffic
  is useless to you even apart from the trademark risk.
- "Rev rate" is a real search with almost no direct competition (LaneTrax,
  BowlTrace, Bowldyna). Leave it out until rev rate ships. Listing a feature the
  app doesn't have breaks 2.3.1 and 2.3.7.
- What reviewers complain about, from the words in LaneTrax reviews: "rev rate",
  "lane detection can be finicky", "pain to get it to detect the lane/foul line",
  "sick and tired of everything being a subscription", "there needs to be a one
  time purchase option". No review used "entry angle". Bowlers care about it once
  they see it, but they don't search for it.
  [LaneTrax reviews](https://apps.apple.com/us/app/id6475736816?see-all=reviews)

The competition got bigger in 2026. From Apple's search API (`itunes.apple.com/search` and `/lookup`):

| App | Released | Pitch | Notes |
|---|---|---|---|
| LaneTrax | Jul 2025 | path, speed, **rev rate** | 670 ratings, 4.8; subscription; account required |
| Striker: Bowling Coach | Aug 2026 | 4-corner calibration, path, spare recs | 0 ratings |
| BowlTrace | Jul 2026 | "Trajectory, speed & rev rate", auto lane detect, oil patterns | 0 ratings, on-device, collects analytics |
| Bowldyna Studio | Aug 2026 | rev rate, axis rotation, physics sim | **free, no IAP, Data Not Collected** |
| AI Bowling | Jan 2024 | trajectory, speed, entry angle | 4 ratings, 3.25 stars |
| Tenpin Toolkit | 2018 | manual speed/RPM tools, overlays | 870 ratings, 4.9; owns "tenpin" |

This doesn't change the plan, but it changes the pitch. "No account, on device"
alone no longer sets TrueLine apart, because Bowldyna does it for free. What does
set it apart: accuracy you can check (the drift check, the board fix), the
session consistency view, a one-time price, and rev rate soon.

### Subtitle

Change it to **Speed, entry angle, breakpoint** (30 characters). Reasons:

- Apple weights the subtitle more than the keyword field. "Breakpoint" is a word
  serious bowlers use, and only TrueLine and Striker put it up front.
- "Hook" moves to the keyword field. Nobody autocompletes it, and it drags in
  generic results.
- When rev rate ships, change it to **Speed, rev rate & entry angle** (29
  characters). That will be the single best listing change available.

An alternative, if you want the setup in the subtitle: **One iPhone. Real ball
tracking.** Avoid "Pro" and "accurate" in the subtitle (see section 4).

### Keyword field

Rules: commas, no spaces, no plurals of words you already have, nothing that is
already in the name or subtitle. The name gives TrueLine, Bowling, Ball,
Tracker. The new subtitle gives Speed, Entry, Angle, Breakpoint.

**Recommended (98 characters):**

```
trainer,coach,stats,analysis,meter,hook,arrows,league,practice,tenpin,lane,video,pocket,boards,pin
```

Each word combines with the name and subtitle: "bowling trainer", "bowling
coach", "bowling stats", "bowling analysis", "bowling speed meter", "ball speed",
"tenpin", "bowling practice", "bowling video", "pocket". "Pin" is weak. Swap it for "arsenal"
(you'd have to drop something else for room) if the per-ball compare screen
becomes a lead feature.

Notes on the candidates in `app-store-listing.md`:

| Candidate | Verdict |
|---|---|
| ballspeed | Drop. People type two words, and "ball" plus "speed" are already covered. |
| entry, angle, breakpoint | Move to the subtitle (higher weight). |
| arsenal | Maybe. "bowling ball arsenal" autocompletes, but that's ball-database apps. Low fit. |
| boards | Keep. |
| practice | Keep. |
| analyzer | Use "analysis". "bowling analyzer" autocompletes to a cricket app. Apple's matching of stems is not documented, so don't spend characters on both. |
| pba, usbc | Drop (trademarks, see section 4). |
| oil, pattern | Drop. The app doesn't read oil, and BowlTrace does. Listing it would be misleading. |
| strike, spare | Drop. These pull in game players ("bowling strike 3d") and score keepers. |
| rev | Hold until rev rate ships, then add "rev" and "rpm" and put rev rate in the subtitle. |

Check after 30 days: App Analytics shows which search terms led to downloads.
Swap out any word that brought in nothing.

## 3. Launch with no budget

### Timing

- **Now to early Dec:** alley session, then submit 1.1. Aim for about Dec 10.
  Apple keeps App Store Connect open over the holidays but reviews slow down from
  roughly Dec 20 to 27.
  [MacRumors 2024 notice](https://www.macrumors.com/2024/12/02/app-store-review-times-holidays/)
- **Mid Dec to early Jan:** TestFlight round with college clubs over winter
  break, when students bowl at home. Collect comparisons against the speed shown
  at the center.
- **Mid Jan to late Feb:** the public push. League bowlers are halfway through
  the season and know their weaknesses. Tournament bowlers are getting ready for
  the spring events, which start Feb 27. Post the results, not just the app.
- **March:** USBC sectionals for college teams (2026 sectionals included one in
  Pittsburgh). Coaches want consistency data then.
  [Adrian College recap](https://adrianbulldogs.com/news/2026/3/18/womens-bowling-bowling-competes-at-usbc-sections-in-pittsburgh.aspx)

### r/Bowling

I could not read the subreddit's rules. Reddit blocks automated fetches, and I
did not try to get around that. **Read the sidebar and wiki yourself before
posting.** What usually holds on hobby subs of this size: many ban plain ads,
some allow them only in a weekly thread, and almost all give a pass to an open
"I made this, looking for feedback" post from someone who already comments
there. A ban is permanent.
[Redship guide](https://redship.io/blog/reddit-self-promotion-rules)
In practice:

- Comment on a few form and ball-motion threads in December, as yourself.
- Message the mods first: "I'm the solo dev of a ball-tracking app. Is a single
  feedback post OK, and should it go in a particular thread?" Mods rarely say no
  to someone who asks.
- One post. Put a real clip and real numbers in it. Answer every comment,
  including the critical ones. Give TestFlight or offer codes in replies to the
  people who ask.

### Facebook groups and Discord

The big bowling Facebook groups (league, coaching and ball-review groups) post
their rules in a pinned "Rules" post or in the join questions. I couldn't
research them from outside Facebook. Same approach as Reddit: ask an admin, post
once, lead with a clip. Discord servers for college bowling teams and for
bowling YouTubers often have a #tools or #self-promo channel. Use that channel
only.

### YouTube bowling coaches

My searches didn't confirm specific channels, so pick them by hand. Look for
mid-size coaches (5k to 100k subscribers) who already film from behind the
approach or talk about entry angle. The National Bowling Academy and Bowling This
Month both publish entry-angle content.
[NBA videos](https://www.nationalbowlingacademy.com/videos/all-videos),
[BTM entry angle](https://www.bowlingthismonth.com/bowling-tips/entry-angle-assessment/)
The pitch: a free unlock through a one-time offer code, no script, and "tell me
where it gets your numbers wrong". Coaches like a tool they can test. The FTC
expects them to say they got it free, and you shouldn't ask them not to.
[FTC influencer guide](https://www.ftc.gov/business-guidance/resources/disclosures-101-social-media-influencers)

### League secretaries and pro shops

- **League secretaries** control the league email or group chat. Many use the
  League Secretary app (2,678 ratings). Ask them to forward a short note and a
  custom offer code for their league. Don't ask them to endorse the app.
- **Pro shops** are the best channel per hour spent. After drilling a ball, the
  operator wants to show the customer how it moves. Offer the shop one free
  unlock for its own phone and a **custom offer code** (for example the shop's
  name) for customers, with a limit like 50 redemptions. One code per shop also
  tells you which shops actually send people.

### College bowling near CMU

I found no CMU bowling club. CMU's club sports list I could see doesn't include
one ([CMU admissions](https://www.cmu.edu/admission/campus-experience/activities-and-engagement)),
and the athletics page blocked my fetch. Check TartanConnect. If CMU has no club,
starting an informal one is a good story but a lot of work. The nearby programs
are better targets:

- **Duquesne women's bowling** (NCAA Division I, in Pittsburgh).
  [2025-26 schedule](https://goduquesne.com/news/2025/8/26/womens-bowling-duquesne-announces-2025-26-schedule.aspx)
- **Robert Morris** women's club bowling.
  [RMU club schedule](https://rmuclubsports.com/sports/womens-bowling/schedule)
- **Pitt Bowling Club** (already in the notes).
- **CCAC** and **Penn Highlands** junior college teams.

Go through the head coach, and offer the whole team the app through TestFlight
or codes. For NCAA athletes, keep it to the team and the coach rather than
individual free gifts, so nobody has to think about benefit rules. Coaches will
care most about CSV export and session spread.

### Offer codes (verified)

Confirmed by Apple: since **March 26, 2026** you can't create new promo codes for
in-app purchases. Offer codes now cover non-consumables. Promo codes for free app
downloads still exist, but TrueLine is already free, so they don't help.
[Apple news](https://developer.apple.com/news/?id=gf6mgrs6)

How they work for a non-consumable
([Apple help](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases)):

- Up to 10 active offers per app. Codes can be one-time-use (500 to 25,000 per batch)
  or custom (a word you choose, with a redemption limit). Up to 1 million per
  quarter. One redemption per customer per offer.
- One-time codes must expire within 6 months. Custom codes can be set to never
  expire.
- You can set an offer to **Free** and limit it to people who have never
  purchased.
- You can only create real codes once the app is "Ready for Distribution" and the
  IAP is approved. Sandbox codes work at any time, so test with those first.
- Redemption through the URL or the App Store needs no app code. TrueLine's
  `TruelineStore` already listens to `Transaction.updates`, which is how a code
  redeemed outside the app should unlock it. Confirm with a sandbox code on a
  device before giving any codes out. In-app redemption (the
  `offerCodeRedemption` sheet) is optional, but a "Redeem code" row in Settings
  makes pro shop codes easier to use.

### Review prompts and the first 20 to 50 ratings

The prompt rule on `stage` (after 3 good results, on the way home, once per
version) already follows Apple's guidance. Guideline 5.6.1 requires Apple's API
for the prompt. 5.6.3 forbids manipulating reviews. Asking for a review is fine.
Paying for one, or making a code depend on one, is not.

Honest ways to get ratings:

1. **1.0 users:** the 1.1 update plus the What's New sheet gets them back into
   the app. The prompt fires after their 3rd good result. These are the most
   likely early ratings.
2. **TestFlight testers:** TestFlight builds can't be rated. Once 1.1 is live,
   send one message: "1.1 is live. If it's been useful, an honest rating helps a
   solo app a lot." Send it once, with nothing attached to it.
3. **Pro shops and coaches** who use it with customers. A rating is never part
   of the deal.
4. **Reply to every review** in App Store Connect, short and specific. 5.6.1 says
   no marketing in replies.
5. Don't ask friends who don't bowl. It breaks the spirit of 5.6.3, and their
   reviews say nothing useful.

A realistic goal is 20 ratings by the end of February from roughly 30 testers, a
few hundred downloads from the push, and the 1.0 users coming back.

### Two example posts

Plain on purpose. Fill the brackets with real results from the alley session.

**r/Bowling (only after reading the rules or getting a mod's OK)**

> **I built an iPhone app that tracks the ball from behind the approach. Looking for people to tell me where it's wrong.**
>
> I'm a college student and I bowl in a league. Over the last year I built
> TrueLine. You put your phone on a tripod behind the approach, bowl, and it
> shows ball speed, board at the arrows, breakpoint, entry board and entry angle.
> Everything runs on the phone. There's no account.
>
> Here's a session from last week [clip]. The app had my entry at [board] on the
> strike and [board] on the light hit, and the center's speed display was within
> [x] mph of it on most throws.
>
> Things it doesn't do yet: rev rate (I'm testing it with a 240 fps camera), and
> it gets worse if the phone is tilted a lot or way off to the side.
>
> The first 25 throws are free, and after that it's a one-time $14.99. If you
> want to try it and tell me where the numbers look off, I'd really like that
> feedback. I can also send a TestFlight invite for the next version.

**Email to a college coach or pro shop**

> Subject: Ball tracking app for your team, free to try
>
> Hi Coach [name],
>
> I'm Adam, a student at Carnegie Mellon. I made TrueLine, an iPhone app that
> measures ball speed, arrows board, breakpoint and entry angle from one phone
> on a tripod behind the approach. It runs on the phone and doesn't collect any
> data.
>
> I'd like to give your team free access for the rest of the season. In return
> I'm asking for honest feedback, mostly about where the numbers disagree with
> what you see. It also exports each session to CSV if you want to track your
> bowlers' spread over time.
>
> I can come by a practice to help set it up. Would that be useful?
>
> Thanks,
> Adam Zhu

## 4. App Review risks for 1.1

Ordered by how likely each is to cause a rejection.

1. **Describe new features in the Review Notes (2.3.1).** The guideline says new
   features "must be described with specificity in the Notes for Review ... generic
   descriptions will be rejected." List all of them: the drift check, the What's
   New sheet, the 25 free throws, failure reasons that don't use up a throw,
   CSV export, Send Feedback (mail), Rate TrueLine, and zoom.
   `app-review-notes.md` still says 10 throws and has a placeholder for the
   sample video.
2. **Repeat 2.1 "information needed".** 1.0 was held until Apple got a screen
   recording. For 1.1, attach from the start: a link to the sample video (your
   own footage), a screen recording of the core flow, and the purchase sheet.
   This saves a round trip, which matters in December.
3. **Camera purpose string (5.1.1).** The current one, "TrueLine records your throw
   to analyze the ball path.", passes. A fuller version is safer and helps your
   privacy pitch: "TrueLine uses the camera to record your throws and track the
   ball. Videos are analyzed on this iPhone and never uploaded." There is no
   microphone string, so make sure the capture session adds no audio input. The
   camera roll import should keep using PhotosPicker, which needs no
   permission. If you ever save to Photos, you need an add-only photo library
   string.
4. **Paywall and prices.** Restore is in both places it should be, and the price
   comes from StoreKit. One small issue: when the product doesn't load, the
   button falls back to a hard-coded "$14.99" (`PaywallView.price`). That's wrong
   in non-US storefronts and could read as "a false price" under 2.3.1.
   Better: show a spinner or disable the button until `product` loads. Also, the
   button label in that view puts an em dash before the price, which breaks the
   app's own copy rule.
5. **Accuracy claims (2.3.1, 1.1.6).** Don't say "pro-accurate", "same as
   Specto" or give board-level accuracy unless you publish how you measured it.
   1.1.6 forbids false device data, and the 1.0 offset shows how a confident
   number can be wrong. Safer wording for the description: "the same kinds of
   numbers in-center tracking systems show". The current "the numbers serious
   bowlers pay thousands to get" could get pushback. Specto costs about $10 a
   session for a bowler, so soften it. Section 1.4.1 (medical accuracy) doesn't
   apply, even with Health & Fitness as the secondary category.
6. **USBC and PBA (2.3.7, 5.2.1).** 2.3.7 says not to pack metadata with
   trademarked terms, and 5.2.1 says not to use them without permission. Remove
   both from the keywords as planned. I found no public USBC rule on using its
   name. A factual line in the description like "some tournaments don't allow
   recording, so check the event rules" does the same job without naming USBC.
   Comments in the code that mention USBC and Specto are not metadata and are fine.
7. **Free-throw model under 3.1.1.** It's fine. Unlocking with a non-consumable
   IAP is the standard path, and a free allowance counted per use is not the
   time-based trial that needs the "XX-day Trial" product. 1.0 was approved this
   way. Keep it clean: the paywall says how many free throws there are (it does),
   the description says 25 only once 1.1 is live, screenshots don't mention free
   throws (2.3.7 prices), and offer codes are never tied to reviews.
8. **Screenshots must match 1.1 (2.3.3).** If you keep the Aug 15 set, check that
   no screen in it changed in a way a reviewer would notice. Upload a 1206 x 2622 set
   too, since Apple's page now lists that size as required.

## Sources not linked above

- Apple App Store search API, run Nov 3 2026: `itunes.apple.com/search` and
  `/lookup` for competitor names, release dates, rating counts and descriptions.
- Apple App Store search hints (autocomplete), run Nov 3 2026, US storefront.
- [TrueLine on the App Store](https://apps.apple.com/us/app/trueline-bowling-ball-tracker/id6801953797): 2 ratings, 5.0, version 1.0.
- [StrikeMaster](https://apps.apple.com/app/id6742661765), [BowlTrace](https://apps.apple.com/us/app/id6792940057), [Bowldyna Studio](https://apps.apple.com/us/app/id6794239770) product pages.
