# Target read, transition hint and CSV target column: research

Written Nov 15, 2026, for the prototype on `next/target-and-transition`
(`TargetRead.swift`, `LaneTransition.swift`, `ShotCSV.swift`). Right-handed
terms unless noted; boards are hand-normalized in the code, so "inside" is a
higher board for both hands. Sources are at the bottom of each section. Where a
page could not be read in full (paywall, bot wall), that is noted.

## Recommendations

### 1. Tolerance for "hit your target"

Always show the exact board ("Crossed 11, target 10"). Grade it in three steps,
using the same rounded board the headline shows:

- **On target:** crossed the target board itself (rounded board equals target).
- **1 off:** rounded board is one away. Shown as "1 board inside" or "1 board
  outside", but it still counts as hitting your mark for the "was it me or the
  lane" verdict.
- **Missed:** two boards or more. This is the only grade that produces the
  "execution" verdict.

Session stats should carry both numbers: "On target 6 of 15, within 1 board 12
of 15". The exact number honors the "hit my target means hit the board"
standard for players who want it; the within-1 number is what the verdict uses.

Why not exact-board for the verdict:

- A ball-throwing robot misses by more than a board at the arrows about one shot
  in ten (USBC's E.A.R.L.). That implies a spread of roughly 0.6 boards at the
  arrows, so an exact-board rule would call about 4 in 10 of a robot's shots
  "execution".
- The informal standard among coaches and serious bowlers is "within a board".
  GoBowling's sample practice goal is 20 of 30 shots on the intended arrow
  within one board. LaneTrax's top consistency tier is 1 board or less. Forum
  regulars treat 1 to 2 boards as a normal miss and 3 as a big one.
- Motor-learning research that bowling coaches cite (bandwidth feedback) says
  feedback works better when small errors inside a tolerance band get no
  correction. Calling every 1-board miss "execution" is the after-every-shot
  correction the research warns against.
- With about 0.15 boards of measurement error, roughly 30 percent of shots land
  close enough to a half-board boundary that "on the board" against "1 off"
  could flip on noise. That is fine for a displayed grade. It is not fine for a
  verdict that tells the bowler whether to move.

Two refinements, both from the evidence below:

- **Classify on the rounded board, not the raw miss.** The prototype uses
  `abs(arrow - target) <= 1.0`, while the headline rounds the board. A shot at
  9.1 and one at 8.9 both read "Crossed 9, target 10", but the first is "on your
  mark" and the second is "1 board outside your mark. That's execution". Using
  the rounded board (within-1 means |miss| < 1.5) makes the grade match the
  number on screen. Also, the comment on `markTolerance` says the arrows
  measurement is "about a board"; it is now about 0.15, so that reason no longer
  holds. The real reasons are the robot spread and coaching practice.
- **Hitting the mark is necessary for "the lane", not sufficient.** Coaches
  point out that you can hit the arrows at a different angle (single-point
  targeting, Kegel's Rick Wiltse) or with a different speed. Before saying "the
  lane", check that launch speed is within about 0.5 mph of the session median
  (Specto: pros hold launch speed within 0.5 mph) and, if available, that the
  foul-line board is within about 2 boards of its median. If either is off,
  say so ("You hit your mark, but this one was 0.9 mph slower than your
  average") rather than blaming the lane.

One unrelated thing found while reading the prototype: `LaneModel.pocketBoards`
is 17 to 18. Specto's pocket window is 16.5 to 17.5 and USBC's ideal is 17.5.
A 16.8 entry is a pocket hit to Specto and "light" to TrueLine. Worth a second
look before this verdict ships.

Confidence: medium-high that ±1 (rounded) is the right line for the verdict;
there is no published standard, but every source that gives a number lands on
"within a board".

### 2. Live hint during a session

Show data first and keep the hint, but only as a quiet suggestion that appears
after enough good shots, never after one shot, and never as an instruction.

- **Evidence before a hint:** at least 4 of the last 5 shots on the current
  target that were on the mark (within 1), with the breakpoint drifting at
  least 1.5 to 2 boards relative to the arrows across them. The prototype's
  window (5), minimum (4) and threshold (1.5 boards) match the only published
  rule of thumb found (BowlersMart: at least 5 shots before a major change; when
  the breakpoint migrates 2 or more boards across 3 shots, make a small move).
  The change to make: drop shots that missed the mark from the window instead of
  only checking that arrows "held" overall, because coaches agree you cannot
  read the lane off a shot you didn't execute.
- **Better still, require a pocket symptom too:** 2 of the last 3 on-mark shots
  high (for the "move in" hint) or light (for the "move out" hint). The ball
  moving in a board is something the bowler cannot feel; the 4 pin, the 10 pin
  going straight back, or a 3-6-10 leave are what tell them it is time.
- **Which move:** the standard first move for transition is the 2-and-1 toward
  the oil: feet 2, target 1, same direction. For a right-hander hitting high as
  the heads dry, that is left (target 10 becomes 11). For a left-hander it is
  right. If the ball is going longer (carrydown, breakpoint moving out, hitting
  light), the mirror move is right for a right-hander, but this is less
  predictable, and the current softer copy ("some bowlers move right a board or
  two") is the right tone. Keep the parallel move out of the transition hint:
  it shifts the whole line sideways and is the move for "I'm in the wrong part
  of the lane", not "the lane is hooking more". Don't escalate to 3-and-1 on
  your own; if the drift continues after a move, suggest another 2-and-1.
- **Keep it out of the record screen and out of the way.** Coaching research
  cited in Bowling This Month favors summary feedback every few shots over
  feedback on every shot, and Steve Fuhrman's habit is "take three shots and
  then discuss". College players also have a coach making these calls, so the
  app should read like a teammate's observation ("Many bowlers move 2 and 1
  here"), which the prototype already does.
- **Lefties:** mirror the direction. Coaches say lefties more often adjust with
  hand position and speed, and that the right-handers' moves left eventually
  wreck the left side's oil. Because the hint reads the bowler's own breakpoint,
  it adapts to how fast their side changes without a separate rule.

Market check: Specto and LaneTrax show data and do not suggest moves. Newer
phone apps do: Striker ("Bowling Coach: Shot Tracker") has a planner with "where
to stand and where to aim" and "estimated miss room", and LaneSight gives "a
one-line adjustment call" on its paid tier. A careful, evidence-gated hint is
in line with where the category is going, and gating it on on-mark shots is
something none of them describe.

Confidence: medium. Coaching agreement on "only adjust off good shots" and "small
moves first" is strong; the exact shot count and board threshold are rules of
thumb, not research.

### 3. CSV target column

Yes. Add the target. Append two columns at the end (the CSV contract keeps
existing columns in place):

- `target_board`: the board the bowler set, blank when none was set.
- `target_miss_boards`: board at the arrows minus target, one decimal,
  hand-normalized (positive is inside, negative is outside), blank without a
  target.

Leave the verdict (on target, 1 off, missed; me or the lane) out of the CSV. It
depends on a tolerance a coach may want to set differently, and both columns
above let a spreadsheet recompute it in one formula. If the CSV does not
already say which hand the boards are counted from, a `hand` column would make
the file self-explanatory when shared with a coach.

Why: every practice log and coaching drill found records the intended target
next to where the ball went. Spare notebooks list "visual target" and "whether
the ball crossed the selected target". GoBowling's practice log is the starting
board, finishing board and where the ball crossed the arrows. Bowlingball.com's
drill is calling your mark and counting hits out of ten. Specto's data has no
intended-target field and no documented CSV export (only in-app sessions, a
fixed "custom position" marker and a broadcast API), and LaneTrax exports PDF
only, with CSV and "a new targeting system" both on its roadmap. Target plus
actual in one export is something neither offers today.

Confidence: medium-high that coaches want it; low certainty on what Specto's
coaches app exports, because nothing about it is published.

## Evidence

### How accurate are bowlers at the arrows, and what counts as a hit

**Machine baseline.** USBC's technician blog on E.A.R.L. (its ball-throwing
robot) estimated a launch-angle standard deviation of about 0.2 boards and
concluded the machine "is liable to miss by more than one board at the arrows
either way once in every 10 shots", and that over a 900 series "there will be
three to four balls that may be largely off target". If misses at the arrows
are roughly normal, missing by more than a board 10 percent of the time means a
standard deviation of about 0.6 boards at the arrows. Hitting the exact board
(within half a board) would then happen about 60 percent of the time. This is
the strongest number found for how hard exact-board accuracy is.
https://blogs.bowl.com/the-technician-2

**College players.** A Kegel Training Center study (Feb 2011, Webber
International University players, measured with C.A.T.S.) reported that after
training with three-point targeting and quiet eye, six of seven players
improved consistency at 15 feet by an average of 0.79 boards, and breakpoint
consistency by 4.4 boards over ten shots. The per-player ranges were in a table
image that is not readable, but improvements of most of a board at 15 feet only
make sense if the starting spread was well over a board. Joe Slowinski,
Bowling This Month, April 2011.
https://www.bowlingthismonth.com/bowling-tips/proven-techniques-for-effective-breathing-and-targeting/

**Specto.** Specto defines arrows as the ball position at 15 feet and says "it
is good to be able to consistently hit different targets all the way from 1 to
25". It publishes no tolerance. Its Wheel of Targets challenge (2020) gives
three attempts at each of eight random targets, scoring 3, 2 or 1 points by
attempt, with three difficulty levels. What counts as a hit at each level is not
published anywhere I could find; the difficulty levels most likely change the
board window, but that is a guess. The 2019 ranking report added an "accuracy
score" combining "where the player is at the four primary locations measured",
with no formula given. Wichita State's tryout scoring (seen in search results,
since removed) rated players on the range of laydown, arrows, breakpoint, launch
angle and speed over 15 shots.
- https://www.spectobowling.com/tutorialperformance
- https://www.spectobowling.com/news/2019/12/13/new-specto-ranking-report
- https://www.angularvelocity.fi/news/specto-bowling-new-challenge

**LaneTrax.** Its session ranking grades strike-shot arrows consistency in five
levels: level 5 is 1 board or less, level 4 is 2 or less, level 3 is 3, level 2
is 5, level 1 is more than 5. The figure is the average of shot-to-shot arrows
differences after throwing out the largest half "to account for adjustments".
That is a graded band with one board at the top, and it measures consistency,
not hitting a declared target, since LaneTrax has no target setting yet.
https://docs.lanetrax.app/ios/pastsessions/past-sessions.md

**GoBowling arrow guide.** Sample goal: "Out of 30 shots, I want at least 20 to
hit my intended arrow within one board." It also states the app's exact logic:
"If you hit your target and see a very different reaction than earlier in the
session, that's a sign the lane has changed", and "If you miss both your arrow
and the pocket, that's more about execution", with the advice to wait for a
pattern before moving.
https://gobowling.com/blog/bowling-arrow-guide-how-to-use-lane-arrows/

**Forums (anecdotal, read through search summaries because the sites block
automated reading).**
- BallReviews "How much of a miss is a big miss?": "3 boards = a big miss"; one
  poster keeps misses "within 2 boards"; another says a 1 to 2 board miss is
  usually manageable. One notes a 1-board miss matters more on a swing shot than
  a direct line, and that some sport patterns still have 4 boards of area.
  https://ballreviews.com/miscellaneous/how-much-of-a-miss-is-a-big-missa
- BowlingBoards "How accurate are you aiming at the arrows?": posters report
  2 to 3 boards of spread, "most of the time within a board", and the point
  that many elite bowlers "miss it by the same amount each time", so
  consistency matters more than the exact board.
  http://www.bowlingboards.com/threads/18411-How-accurate-are-you-aiming-at-the-arrows
- Mr Bowling 300 "Hitting your mark": a coach says staying within a board or two
  of the target on a steady basis is good, and a house shot has 3 to 4 boards of
  area at the arrows that still reaches the pocket.
  https://www.mrbowling300.net/post/hitting-your-mark-6156781

**How spotting works in coaching.** Bowlingball.com's "Are You Really Hitting
Your Bowling Mark" uses a spotter calling the board where the bottom of the
ball crosses (aiming at 10, spotter calls 8, you are missing outside). A
related drill is calling ten shots and counting how many hit the mark. (Read
through search summary; the site sits behind a bot check.)
https://www.bowlingball.com/BowlVersity/are-you-really-hitting-your-bowling-mark

**What a one-board miss does at the pins.** Bill Sempsrott (Bowling This Month,
"The Fundamentals of Target Line Adjustments") works the geometry: the common
"3 boards at the pins" figures are wrong, and a 1-board target change moves the
ball about 2.5 boards at the pins on a straight line; on a flat pattern a
1-board feet move shifts entry by about 1.8 boards. So a 1-board miss at the
arrows can by itself explain a slightly high or light hit on a flat sport
pattern, while on a house shot the oil hides it. This is why the verdict should
wait for a repeat before blaming the lane.
https://www.bowlingthismonth.com/bowling-tips/the-fundamentals-of-target-line-adjustments

**Hitting the arrows is not the whole line.** Kegel's Rick Wiltse: a single-point
target "can be hit at an infinite number of angles", which is why Kegel teaches
two or three points. John York (Wilmington University NCAA coach) wrote a
Bowling This Month piece titled "Targeting: Modern Bowling's Overrated
Priority" arguing hitting the target is not the main ingredient of scoring
(paywalled past the intro).
- https://www.kegel.net/articles/tag/Rick+Wiltse
- https://bowlingthismonth.com/bowling-tips/targeting-modern-bowlings-overrated-priority

**Books.** I found nothing quotable on arrows tolerance in Mark Baker's "The
Game Changer" (2012); only the publisher listing is online.

### Feedback during a session

**Bandwidth feedback.** Chris Mesagno (Bowling This Month, May 2013) defines it as
"a tolerance level to establish when feedback is provided", gives no feedback
inside the band, and cites Sherwood (1988): the group given feedback only past a
10 percent error band was the most accurate. Novices get a wider band; advanced
bowlers a narrower one. A related column (Oct 2013) says "providing feedback on
all shots may not be the most effective method", recommends summary feedback
"after a certain number of shots", and quotes coach Steve Fuhrman: "I like to
have students take three shots and then discuss" and "I don't provide feedback
on every shot."
- https://www.bowlingthismonth.com/bowling-tips/bandwidth-feedback/
- https://bowlingthismonth.com/bowling-tips/how-coaches-can-best-apply-feedback
- Lee and Carnahan (1990), bandwidth feedback better for retention than matched
  frequency controls: https://data.zhenzhi.com/details/1/1002106830/1/2

**Only adjust off good shots.** Nick the Bowling Coach: "You can't make
lane-play decisions off a shot you didn't throw well", and a missed target can
still finish high for reasons unrelated to the lane (read through search
summary; the page would not load). MDM Coaching warns about adjusting off bad
ball reaction.
- https://nickthebowlingcoach.com/move-toward-your-miss-in-bowling-but-only-if-you-read-it-correctly/
- https://www.bowlersmart.com/2020/03/19/bowling-adjustments-including-bowling-balls-and-lane-play-by-mdm-coaching/

**How many shots.** BowlersMart's block guide: "Throw at least 5 shots before
making a major change", and later "When it starts to migrate (2+ boards across 3
shots), make a small move before you get burned by a bad shot." Bowlers Depot:
"Start small, one or two boards before you go bigger", and most transition is
solved with a 1 to 3 board move toward the oil (left for right-handers).
- https://www.bowlersmart.com/learn/tips/advanced-bowling-tips/
- https://bowlersdepotlargo.com/how-to-read-the-lanes-when-transition-happens-and-stop-leaving-pins-behind/

**Move types and direction.** USBC: move "in the direction of the miss while
keeping the same target"; 2-and-1 is "for every two boards you move with your
feet, you move your target one board in the same direction" (20 looking at 10
becomes 22 looking at 11); a parallel move is feet and target "the same amount
and in the same direction"; "As the lanes start to hook more, you might move your
starting position one board to the left"; lefties are the mirror. National
Bowling Academy: the 2-and-1 keeps the ball near the same breakpoint while
changing the angle, and the first sign on a good shot is often a 4 pin or a
3-6-10. Bowlingball.com: a dried-out head can need 4 or 5 boards with the feet
and 2 with the target.
- https://bowl.com/making-in-game-adjustments
- https://www.nationalbowlingacademy.com/post/how-bowlers-can-adjust-as-lanes-transition
- https://bowlingball.com/BowlVersity/what-is-bowling-lane-oil-break-down

**Lefties.** National Bowling Academy: lefties more often make "smaller moves
using hand position and ball speed", and right-handers' moves left eventually
infringe on the left-hander's shot. The common belief that the left side
transitions more slowly because fewer people bowl there was not confirmed by
any source I found.
https://nationalbowlingacademy.com/post/lefties-feeling-left-out

**What other tools do.**
- Specto: shows the current shot against the previous one (Deep Practice, Dual
  Deep Practice), stores sessions, has challenges. No move suggestions found.
  https://www.spectobowling.com/tutorialperformance
- LaneTrax: per-metric trend graphs and consistency grades, no move
  suggestions; developer says a "new targeting system" is planned.
  https://docs.lanetrax.app/ios/newsessions/classic-mode.md,
  https://apps.apple.com/us/app/lanetrax/id6475736816
- Striker ("Bowling Coach: Shot Tracker", Aziz Saba): "A redesigned Planner shows
  where to stand and where to aim on the lane's own dots and arrows", "Compare
  alternate lines and estimated miss room", "Track lane transition".
  https://apps.apple.com/app/id6800074214
- LaneSight: "suggests when to move or switch balls"; "a one-line adjustment
  call" on the Player tier, breakpoint drift and transition history on higher
  tiers. Triggers and wording not published.
  https://lanesight-website.pages.dev/features.html

### What exports and logs contain

- Specto's table view: foul line, arrows, breakpoint board, breakpoint distance,
  entry board, launch angle, impact angle, launch speed, entry speed, RPM. Its
  glossary adds a fixed "custom position" marker (second arrow from the left),
  not a bowler-set target. No CSV export is documented; the only programmatic
  access is a broadcast API. Specto App Store reviewers complain there is no way
  to review data away from the center.
  https://www.spectobowling.com/specto-terms,
  https://www.spectobowling.com/tutorialperformance
- LaneTrax: PDF reports now; "CSV data exports are also on our roadmap".
  https://apps.apple.com/us/app/lanetrax/id6475736816
- Spare notebook template: before each attempt record starting foot position,
  visual target, speed cue and the leave; after, record converted, missed left,
  missed right, or execution unclear; "Also note whether the ball crossed the
  selected target."
  https://starlitebowling.com/bowling-spare-practice-routine/
- GoBowling practice log: starting board, finishing board, and where the ball
  crossed the arrows against the chosen target.
  https://gobowling.com/blog/bowling-arrow-guide-how-to-use-lane-arrows/
- Joe Slowinski's spare sheet is per-leave counts (spare, frequency,
  conversions, percentage), and his scoring-data article is counts (first
  shots, pocket hits, pocket strikes); neither is per shot.
  https://www.bowlingthismonth.com/bowling-tips/collecting-and-analyzing-purposeful-spare-shooting-data/print/,
  https://bowlingthismonth.com/bowling-tips/how-to-arrive-at-more-meaningful-analysis-data

## Gaps

- No published pro or college standard deviation at the arrows from Specto or
  CATS. The robot figure and the Kegel study are the closest.
- Wheel of Targets hit rules per difficulty level are not published.
- Bowlingball.com, Mr Bowling 300, BowlingBoards and Nick the Bowling Coach
  block automated reading; their content above comes from search summaries.
- Asking a Specto center operator to show the coaches app's export menu, and
  asking Adam's college coach what tolerance they use when spotting, would close
  the two biggest gaps.
