# Alley visit checklist

One page, one hour of lane time. The goal is to stress-test capture and to
bring home footage we cannot get any other way. Everything else about the app
can be tested from the couch.

## Before leaving home

- [ ] On-device tracking confirmed working (task #1). If the phone still
      returns zero detection boxes, the visit is still worth it, but treat it
      as a footage-collection trip only and analyze at home.
- [ ] Phone charged, at least 10 GB free storage.
- [ ] Decide how the phone will stand: small tripod, phone stand, or propped
      against a ball bag. Bring whatever that is.
- [ ] Print or load this checklist.

## Setup at the alley

- Placement: behind the approach, down-lane view, single lane, per the
  capture spec. Note roughly how high and how far back the phone sits.
- Calibrate once for that placement before the first throw.
- Write down: center name, lane number, oil pattern if the desk knows it.

## Shot list

### 1. Baseline set (the accuracy corpus)

- [ ] 10 throws from your normal placement, bowled normally.
- [ ] After each throw, jot what you expected vs what the app showed:
      board at the arrows, pocket hit or not, rough speed feel. Guesses are
      fine. We only need to know if the numbers are directionally right.

### 2. Robustness set (try to break capture)

- [ ] 3 throws with the phone deliberately misplaced: one too low, one
      off-center, one tilted.
- [ ] 2 throws opposite-handed, if you can fake a lefty release at all.
- [ ] 1 recording stopped too early, before the ball reaches the pins.
- [ ] 1 recording started late, with the ball already halfway down the lane.
- [ ] 1 throw with someone walking through the frame mid-shot.
- [ ] 1 throw of a neighbor bowling on the adjacent lane visible in frame,
      if the house is busy anyway.

### 3. Keeper footage (App Store needs)

- [ ] One clean, well-lit, textbook shot saved as a raw clip. This becomes
      the App Review sample video and the source for the results-screen
      screenshot. Listing notes say screenshots must come from our own
      field footage, never the IG clips.
- [ ] A full 10-throw session completed and saved in-app, so History, Stats,
      and Session Lines have real data for the remaining screenshots.

## Before leaving the alley

- [ ] Play back two or three clips on the phone to confirm they recorded.
- [ ] Confirm the saved session shows up in History.
- [ ] Nothing deleted at the alley. Triage at home.

## At home afterward

- [ ] Back up all raw clips to the Mac.
- [ ] Run the baseline set through the parity harness (Python vs iOS).
- [ ] File anything broken from the robustness set as its own task.
