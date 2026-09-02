# Alley visit checklist — ground-truth session (v1.1 acceptance)

One page, 60-90 minutes of lane time. This session is the acceptance gate
for v1.1: the app's numbers against physically verified truth. It also
collects the footage for the rev-rate experiment and detector retraining.
Everything else about the app can be tested from the couch.

## What to bring

- [ ] Phone, charged, 10+ GB free.
- [ ] White tape (painter's or athletic) — for the target-board mark and
      the rev-rate ball marker.
- [ ] Tape measure (25 ft or longer helps but any works).
- [ ] A second phone or a friend's phone for 240 fps slow-mo clips, if at
      all possible.
- [ ] Your ball. If you own more than one, bring the one with the most
      visible graphic/logo.
- [ ] This checklist.

## Before leaving home

- [ ] Build to install: v1.1 branch WITH the field-test additions merged in
      (`-fieldFootageMode 1 -bankFreeThrows 100`, Release config). Raw
      footage extraction is non-negotiable for this visit — every analysis
      below happens on the Mac afterward.
- [ ] Run the airplane-mode launch test at home the night before (the
      developer-profile trust check killed the Aug 12 visit).
- [ ] Verify: ~100 free throws in Settings, "Save video with each shot" ON,
      and a discarded test recording shows up in Files → TrueLine →
      FieldFootage.
- [ ] Device-test the new calibration flow at home first on an imported
      alley clip, so alley time isn't spent learning the taps.

## Setup at the alley

- Placement per the capture spec: behind the approach, down-lane view.
  Note how high and how far back the phone sits.
- Write down: center name, lane number, oil pattern if the desk knows it.
- If the house has overhead speed displays, note it — then photograph the
  display after every scored throw. That's free ground-truth speed.

## Shot list

### 1. Calibration flow, for real

- [ ] Run the full 6-tap calibration at the alley. Rough-time it with a
      clock glance; note anything that felt clumsy or ambiguous.
- [ ] Check the drawn pins against the real rack before confirming — that
      judgment call is the product now.
- [ ] Tripod habit: tapping a mounted phone can nudge it AFTER you
      calibrate. Steady the mount with the other hand while tapping, and
      glance at the first throw's review overlay — if it slid off the
      lane, recalibrate before continuing.

### 2. Ground-truth accuracy set (the acceptance test)

- [ ] Put a small tape mark on a known board at the arrows (count boards
      from the right gutter; write the board number down).
- [ ] 10 throws aiming over the mark. After each: jot the board you
      actually crossed (your read), pocket/Brooklyn/miss by eye, pinfall,
      and the overhead speed display if there is one.
- [ ] Acceptance bar: app entry board within ~1 board of reality on clean
      pocket hits, arrow board within ~1 board of the mark when you hit it,
      speeds consistent with the display.

### 3. Drift + re-prop set (the failure modes that burned Aug 17)

- [ ] Mid-session, deliberately bump the phone a little. Confirm the review
      screen's overlay visibly slides off the lane, then recalibrate.
- [ ] Fully re-prop the phone once (pick it up, put it back) and
      recalibrate via the overlay-check path. Note how long it took.

### 4. 2x zoom set

- [ ] 5 throws recorded at 2x. Same note-taking as the accuracy set.
      This footage decides whether impact speed / speed loss become real
      metrics, and whether 2x should be the recommended default.

### 5. Rev-rate experiment set

- [ ] Put a strip of white tape on the ball near your PAP (ask the desk if
      unsure; roughly: right of the fingers for a righty, where the track
      ring doesn't touch).
- [ ] 5 throws with the taped ball recorded normally in the app.
      (Hypothesis: the tape flash is a periodic brightness signal the
      harness can FFT into RPM at 30/60 fps.)
- [ ] 3-5 throws of the SAME ball UNTAPED, also recorded in the app.
      Product decision (Sep 2): rev rate ships marker-less by default —
      the Aug 17 clips already read ~350 RPM off the ball's graphic alone.
      These throws measure how much accuracy the untaped path loses.
- [ ] 3-5 throws at 240 fps slow-mo from the second phone, close behind
      the release — cover BOTH taped and untaped throws if clip count
      allows. These give hand-countable ground-truth revs to validate the
      FFT against, including the flashes-per-rev=1 assumption (a graphic
      visible twice per rev would double the reading).

### 6. Placement robustness set (detector retraining corpus)

- [ ] 3 throws with the phone deliberately misplaced: one low, one
      off-center, one tilted. These extend the batch-2 corpus.

## Habits during the session

- Prefer "Save Shot" over "Discard" even when a result looks wrong — the
  metrics are the accuracy corpus.
- Finish every throw with a button tap before pocketing the phone; a clip
  is only rescued into FieldFootage once a button runs its cleanup.
- Notes beat memory. A board number scribbled per throw is the whole
  point of the visit.

## Before leaving the alley

- [ ] Play back two or three clips to confirm they recorded.
- [ ] Files app → TrueLine → FieldFootage roughly matches the throw count.
- [ ] Photos has the speed-display shots and slow-mo clips.
- [ ] Nothing deleted at the alley. Triage at home.

## At home afterward

- [ ] Pull FieldFootage + slow-mo clips to the Mac, back everything up.
- [ ] Ground-truth scorecard: app vs notes for every accuracy-set throw.
      This table is the v1.1 ship/no-ship evidence.
- [ ] Speed adjudication: launch vs average speed against the display
      photos (the loft-artifact question from the IMG_5108 profiling).
- [ ] Rev-rate harness experiment on the taped-ball clips; hand-count revs
      in the slow-mo for truth.
- [ ] File anything broken as its own task.
