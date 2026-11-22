# TestFlight beta and outreach

Written Nov 15, 2026. The plan for the first outside testers, plus email
drafts Adam sends himself. Timing follows `launch-plan-1.1.md`: submit 1.1
around Dec 10, run the beta over winter break and into January, and do the
public push in late January and February.

Contact routes below were found on public pages on Nov 15. Each one says where
it came from. Where a route could not be confirmed, it says so. Nothing here
was guessed.

## Goal

Find out where TrueLine's numbers disagree with what bowlers see, on phones,
lanes and placements other than Adam's. Secondary goals: a few honest ratings
once 1.1 is live, and taped rev rate clips for `rev-rate-plan.md` stage 6.

Size: 10 to 30 testers. More than that is more feedback than one person can
answer.

## TestFlight setup

**What build.** The approved 1.1 build (version 1.1, build 3 or later) in
TestFlight first. Rev rate builds (1.2) go to the same groups later.

**Groups and links.** Make one external group per target, each with its own
public link. App Store Connect then shows how many people joined from each
club or shop.

| Group | Link limit | Notes |
|---|---|---|
| Pitt Bowling Club | 20 | public link |
| RMU Bowling | 25 | public link, shared by the coaches |
| Duquesne Bowling | 15 | send through the coach; the coach decides whether to share it |
| Pro shops | 5 each | public link per shop, or email invites to the operator |
| Friends and league | 10 | email invites |

How Apple's flow works ([Apple, invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)):

- An internal group has to exist before an external one.
- Add the build to the external group, fill in "What to Test", and the Test
  Information (feedback email and contact).
- "The first build you submit requires a full review, but later builds for
  the same version might not." Allow a day or two for this beta review.
- Create Public Link under the group's Testers tab. Choose "Filter by
  Criteria" and set the minimum iOS version to the app's deployment target,
  so people on older phones aren't let in to a build that won't run. You can
  set a limit from 1 to 10,000 and turn the link off any time.
- Anyone can forward a public link. That's fine here, but use email invites
  for anyone you want to track by name.

**Public link or invites?** Public links for the clubs, because Adam won't
have the members' emails and the officers can post one link in a group chat.
Email invites for coaches and shop owners, so Adam knows who is who.

**Free access.** In-app purchases in TestFlight builds go through the
sandbox and testers aren't charged, so the beta itself is the free access.
Confirm with one purchase in a TestFlight build before telling anyone. Builds
expire after 90 days. When 1.1 is live, give each group a custom offer code
for TrueLine Unlimited (for example PITTBOWL), limited to the group's size
(see `launch-plan-1.1.md`, "Offer codes"). Never tie a code to a rating.

**What to Test text** (paste into TestFlight):

```
Thanks for testing TrueLine. Bowl normally with your phone on a tripod behind the approach. What helps most is telling me where a number looks wrong. Use the screenshot feedback in TestFlight, or email support@truelinebowling.com. Please include your iPhone model, a photo of where the phone was set up, and the speed the center showed for the same throw.
```

## What to ask testers for

Send this list once they join. Keep it to one short email.

1. **iPhone model and iOS version.**
2. **Frame rate.** The app records 1080p at 60 fps where the phone supports
   it. Ask whether they recorded in the app or imported a video, and for
   imports, which camera setting (30 or 60 fps, or slo-mo).
3. **A placement photo.** One picture taken from beside the tripod that
   shows the phone, its height and how far behind the foul line it is. Plus
   a screenshot of the record screen. This explains most tracking failures.
4. **The center's displayed speed** next to TrueLine's for the same throws.
   Tell them these won't match exactly. Many center sensors average over a
   different part of the lane, and TrueLine shows launch speed. A steady
   offset is fine. Scatter is what we want to know about.
5. **Specto numbers**, if their center has Specto. Board at the arrows,
   breakpoint and entry board are the useful ones to compare.
6. **Where the numbers disagree with what they saw.** For example: "it said
   I crossed 12 and I know I hit 10." One line per throw is plenty.
7. **Failures.** The reason screen and what they tried.
8. **The CSV export** of a session, if they're willing.
9. Optional, for rev rate later: a few throws with a strip of tape from the
   PAP past the finger holes, filmed by a friend in slo-mo from beside the
   foul line.

**Privacy.** Testers send photos and maybe clips by email. Tell them clips
are used only to test the app, kept on Adam's machine, never posted, and
deleted on request. Ask before using anyone's footage in screenshots or
the preview video. NCAA athletes (Duquesne) especially: no names or faces in
marketing without the coach's and the athlete's OK.

**Follow-up rhythm.** One message when they join, one check-in after their
first week, and one "1.1 is live" note with the offer code. Reply to every
piece of feedback within two days.

## Targets and contact routes

| Target | Route | Source | Confidence |
|---|---|---|---|
| **Bowling Club at Pitt** (student org, 50 to 65 members listed) | Contact form on the club's page (Contact Us, at experience.pitt.edu/BOWL). The page lists no email. Officers listed: Anya Podsobinski (Vice-President), Stacey Nath (Advisor). | [experience.pitt.edu/BOWL](https://experience.pitt.edu/BOWL/) | Confirmed page. The form may need a Pitt login; if so, ask a Pitt friend to pass the message on, or find the club's tabling at an involvement fair. |
| Pitt club sports office | Not the right route. Bowling isn't on Pitt's club sports list; the club is a general student org. | [Pitt Club Sports](https://studentaffairs.pitt.edu/node/639) | Checked |
| **RMU Bowling** (men's varsity, men's JV and women's teams, run through RMU Club Sports) | John Michalenko, Program Director / Director of Bowling Operations: michalenko@rmu.edu. Instagram: @rmubowling (linked in the site's navigation). | Email in RMU's [2025 youth camp release](https://rmuclubsports.com/news/2025/5/29/rmu-club-bowling-team-to-host-5th-annual-youth-bowling-camp.aspx). Instagram per the site nav on the [Aug 2026 Colonial Classic release](https://rmuclubsports.com/news/2026/8/18/mens-bowling-3rd-annual-colonial-classic-tournament-and-fundraiser.aspx). | Email confirmed in an official release. Staff directory page now returns 404. |
| RMU coaches | 2026-27 men's staff: Ramon Estrada (Men's Varsity Bowling Coach), Felix Estrada and Kendall Battles (assistants). No emails shown. | [RMU men's bowling coaches](https://rmuclubsports.com/sports/mens-bowling/coaches) | Names confirmed; reach them through Michalenko, or through RamFlex below. |
| **Duquesne women's bowling** (NCAA Division I, NEC) | Head coach Jody Fetterhoff, the program's only head coach since 2015. Email fetterhoffj@duq.edu and phone 412-396-4797 appeared in a search summary of her goduquesne.com staff profile, but the page itself wouldn't render for me. **Open her staff profile and confirm the email before sending.** | [Staff profile](https://goduquesne.com/staff.aspx?staff=252), [coaches page](https://goduquesne.com/coaches.aspx?rc=127) | Name and title confirmed. Email not confirmed. |
| **RamFlex Bowling Pro Shop** (inside AMF Mt. Lebanon Lanes, 1601 Washington Rd) | Info@RamFlexBowlingProShop.com, (412) 595-8536 | [ramflexbowlingproshop.com](https://ramflexbowlingproshop.com) | Confirmed on the shop's site. A directory listing says the owners include Ramon and Felix Estrada, the RMU coaches. The shop's site only says "family owned". If true, this one email reaches both a shop and the RMU varsity coach, so write it to work for both. |
| **Glenn's Pro Shop** (inside Arsenal Bowl, 212 44th St, Lawrenceville) | GlennsProShop@gmail.com, (412) 683-5992. Appointment only. Run by Glenn, 40+ years in bowling. | [Arsenal Bowl pro shop page](https://www.arsenalbowl.com/pro-shop) | Confirmed. Closest shop to CMU. |
| **AMF Mt. Lebanon Lanes** (center) | 412-854-0600, or the Contact Us form on the AMF page. It hosts RMU's youth camp and has a league program. | [AMF Mt. Lebanon](https://amf.com/location/amf-mt-lebanon-lanes) | Confirmed. Best approached in person, through the league coordinator, after RamFlex. |
| Duff's Pro Shop (5840 Buttermilk Hollow Rd) | Phone only, through Yelp; the page blocked fetching. | [Yelp listing](https://m.yelp.com/biz/duffs-pro-shop-pittsburgh) | Unconfirmed. Call or visit. |
| Perfect Games (Adam's test center) | In person. Adam has filmed there twice. | own notes | Ask the manager face to face, and offer a code for its league bowlers. |

Later, if the first round goes well: Pitt-Greensburg and Pitt-Bradford have
varsity women's bowling, and CCAC and Penn Highlands have junior college
teams (`launch-plan-1.1.md`). Duquesne's head coach also hosts recruits and
sees a lot of high school bowlers.

Order: RMU and Glenn's first (confirmed emails, active programs), then Pitt
through the form, then Duquesne once the email is confirmed, then the
centers in person.

## Email drafts

Plain on purpose. Fill the brackets. Send from Adam's own address or
support@truelinebowling.com, with the TestFlight link pasted in only after
the beta review has passed.

### Bowling Club at Pitt (contact form or officers)

> Subject: Free beta of a bowling app for the club
>
> Hi,
>
> I'm Adam Zhu, an undergrad at Carnegie Mellon. I made TrueLine, an iPhone
> app that tracks your ball from a phone on a tripod behind the approach. It
> shows ball speed, the board you crossed at the arrows, your breakpoint and
> your entry angle.
>
> I'm looking for a few bowlers to try a beta over winter break and tell me
> where the numbers disagree with what they see. It's free while you test,
> and I'll give testers a free unlock when the update is out. There's no
> account and nothing is uploaded.
>
> If the club is interested, I can send a TestFlight link that you can post
> in your group chat. I'm also happy to come to a club night and help people
> set it up.
>
> Thanks,
> Adam Zhu
> truelinebowling.com

### RMU Bowling (John Michalenko)

> Subject: Ball tracking app for RMU bowling, free to try
>
> Hi Mr. Michalenko,
>
> I'm Adam Zhu, a student at Carnegie Mellon. I built TrueLine, an iPhone app
> that measures ball speed, board at the arrows, breakpoint and entry angle
> from one phone on a tripod behind the approach. Everything runs on the
> phone.
>
> I'd like to offer your men's and women's teams free access through a beta
> this winter. What I'm asking for in return is honest feedback, mostly about
> where the numbers disagree with what your coaches see. Each session also
> exports to a spreadsheet if the coaches want to track a bowler's spread.
>
> Would you be willing to pass this to Coach Estrada and the women's coach,
> or tell me who to contact? I can also come to a practice to set it up.
>
> Thanks,
> Adam Zhu
> truelinebowling.com

### Duquesne women's bowling (Coach Fetterhoff)

Confirm the email first. Keep the offer to the team through the coach, not
to individual athletes, so nobody has to think about benefit rules.

> Subject: Ball tracking app for your team
>
> Hi Coach Fetterhoff,
>
> I'm Adam Zhu, an undergrad at Carnegie Mellon. I made TrueLine, an iPhone
> app that measures ball speed, board at the arrows, breakpoint and entry
> angle from a phone on a tripod behind the approach.
>
> I'd like to offer it to your program free during a beta this winter, for
> you and any of your bowlers you choose. I'm mainly after honest feedback on
> where the numbers disagree with what you see on the lane, and I'd value a
> coach's eye on that. Everything stays on the phone, and sessions export
> to a spreadsheet.
>
> If it would be useful, I can send a TestFlight invite to you first, or
> stop by a practice to show how it works.
>
> Thanks,
> Adam Zhu
> truelinebowling.com

### Pro shop (RamFlex, Glenn's)

For RamFlex, add one line if the Estrada connection is confirmed by then:
"I've also written to RMU bowling about a team beta."

> Subject: Free ball tracking app for your shop
>
> Hi [Glenn / RamFlex team],
>
> I'm Adam Zhu, a student at Carnegie Mellon. I made TrueLine, an iPhone app
> that tracks a bowling ball from a phone on a tripod behind the approach. It
> shows speed, board at the arrows, breakpoint, entry board and entry angle,
> and draws the path on the video.
>
> I thought it might help after a drilling, to show a customer how a new ball
> moves compared with their old one. I'd like to give your shop free access,
> and if it works for you, a code your customers can use to unlock it.
>
> All I ask is that you tell me where the numbers look wrong. Could I stop by
> for ten minutes to show it to you?
>
> Thanks,
> Adam Zhu
> truelinebowling.com

### Bowling center (AMF Mt. Lebanon, in person or by form)

> Subject: Bowling app beta for your league bowlers
>
> Hi,
>
> I'm Adam Zhu, a student at Carnegie Mellon. I made TrueLine, an iPhone app
> that tracks a bowler's ball from a phone on a tripod behind the approach.
>
> I'm running a free beta this winter and would like to offer it to your
> league bowlers. Could I leave a short note with your league coordinator, or
> set up a small sign at the counter? I'd film only with your permission and
> keep other bowlers out of the shot.
>
> Thanks,
> Adam Zhu
> truelinebowling.com

### Welcome note to testers (after they join)

> Thanks for trying TrueLine. A few things help me most:
>
> - your iPhone model,
> - a photo of where your phone was set up, taken from beside it,
> - the speed the center showed for a few throws, next to TrueLine's,
> - any throw where a number looked wrong, and what you saw instead.
>
> Use the screenshot feedback in TestFlight or reply to this email. Short is
> fine. If something breaks, the screen that tells you why is the most useful
> thing to send.
>
> Adam

## Tracking

Keep a small table in this file or a spreadsheet: target, date sent, route,
reply, testers joined (from the group count), feedback received, code sent.
Follow up once after a week with no reply, then stop.
