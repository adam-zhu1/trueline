# Research: how serious amateur bowlers practice, and what TrueLine should do about it

*2026-07-02 · Task #15 · Target user: serious amateurs (league/tournament bowlers
practicing alone who want Specto-like data without training-center prices).*

## 1. The benchmark: what Specto measures

Specto (the in-alley tracking system installed at 250+ centers, used by PBA) is
the product TrueLine substitutes for. Its per-shot data points:

| Specto metric | Definition | TrueLine today |
|---|---|---|
| Arrows board | ball position at 15 ft (where bowlers target) | ✅ "Board at Arrows" (we use the true arrow V, 12–16 ft) |
| Launch speed | speed in the front part of the lane | ✅ Speed (foul→dot timing) |
| Launch angle | direction in the front of the lane (± toward pocket/gutter) | ❌ not shown (derivable from path) |
| Breakpoint board | furthest lateral point of the path | ✅ Breakpoint |
| Breakpoint distance | how far down-lane the breakpoint is (ft) | ⚠️ computed (`breakpointFeet`) but not displayed |
| Entry board | ball position at 59.5 ft | ❌ not shown — trivially extractable from our path |
| Impact angle | angle between 57 and 59.5 ft | ✅ Entry Angle (same concept) |
| RPM / rev rate | rotation | ❌ out of scope for down-lane video (needs ball-surface tracking) |

Reference numbers bowlers know: **entry board 17.5 ≈ 85% strike rate**
(17–18 → strike or single-pin leave 70–85% of the time); **optimal entry angle
≈ 6°**; pros launch 17.5–21 mph with **< 0.5 mph shot-to-shot variance**.

## 2. How this segment actually practices

- 1–2 deliberate sessions/week beyond league night; a session is 1–2 games of
  focused drill work (≈ 20–40 throws) — not casual bowling.
- **Consistency is the product.** Drills are "hit the same target line
  repeatedly"; what they want to see is shot-to-shot variance (target board,
  speed, breakpoint), not one shot's numbers.
- Lane-play adjustment is core skill: reading oil patterns (rule of 31:
  pattern length − 31 = intended exit board), watching the last 20 ft for
  carry-down. They adjust lines mid-session and want to compare before/after.
- Video review is already standard advice ("one video review per session is
  the highest-leverage habit") — TrueLine automates exactly this.
- LaneTalk (500k+ bowlers, official USBC/PBA stats app) owns the *scoring*
  niche: pin leaves, spare %, strike %, and tagging games with **ball, center,
  oil pattern**. TrueLine should not compete on scoring — it competes on ball
  motion — but the tagging pattern (ball/center/pattern per session) is worth
  copying.

## 3. Feature recommendations (mapped to tasks)

**Cheap, do soon**
1. **Entry Board metric** — read path at 59.5 ft. It's *the* number this
   segment optimizes (17.5 = strikes). One function + one tile.
2. **Show breakpoint distance** — display existing `breakpointFeet` alongside
   breakpoint board ("6.0 board @ 42 ft").
3. **Ideal-range hints in UI** — mark 17–18 entry board and 4–6° entry angle
   as target zones on tiles/lane view.

**The session feature (#14) is confirmed as the right bet — extend it**
4. Session = one phone placement + one calibration + N throws (matches drill
   structure). Per-session summary: mean ± spread for speed, arrows board,
   entry board — consistency view first, single shots second.
5. Overlay multiple paths from one session on a single lane view (before/after
   adjustment comparison).

**Later**
6. Tag sessions with ball / center / oil pattern (LaneTalk convention);
   filter history by tag.
7. Target-line practice mode: pick a target board at the arrows,每 throw shows
   hit/miss distance; running accuracy for the drill.
8. Launch angle from the first path segment.
9. Rev rate: not feasible from a single down-lane camera; revisit only if a
   credible technique appears.

## Sources

- [Specto data points](https://www.spectobowling.com/data-points), [Specto terms](https://www.spectobowling.com/specto-terms), [PBA on Specto](https://www.pba.com/2022/december/specto-installed-2023-pba-lbc-national-championships-site)
- [USBC entry-angle research (Stremmel)](https://wiki.maverickbowling.com/wiki/images/c/c6/Entry_Angle_By_Neil_Stremmel.pdf), [IBPSIA Entry Angle Part 2](https://ibpsia.com/entry-angle-part-2/), [bowlingball.com on entry angle & carry](https://www.bowlingball.com/BowlVersity/angle-of-entry-and-bowling-pin-carry)
- [GoBowling arrow targeting](https://gobowling.com/blog/bowling-arrow-guide-how-to-use-lane-arrows/), [BOWL.com reading the lane](https://bowl.com/reading-the-lane), [National Bowling Academy rule of 31](https://www.nationalbowlingacademy.com/post/next-level-lane-play-understanding-rule-of-31-and-ball-motion), [Ron Clifton breakpoints & target lines](https://www.bowl4fun.com/ron/btm01_files/btm1.htm)
- [LaneTalk features](https://lanetalk.com/bowling-score-tracker-features/), [ballerzsportsclub practice guide](https://ballerzsportsclub.com/how-to-improve-bowling-accuracy-fast/)
