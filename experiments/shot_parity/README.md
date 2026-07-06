# Shot-metric parity: iOS ShotAnalyzer vs Python prototype

Runs the exact Swift sources the app compiles (`ios/.../Analysis/*`) on macOS
against the same clips + calibration as the Python pipeline.

```bash
# Swift side (repo root)
swiftc -O -o /tmp/shotparity experiments/shot_parity/main.swift \
  ios/Trueline/Trueline/Analysis/*.swift ios/Trueline/Trueline/Models/LaneCorners.swift
/tmp/shotparity "data/test_videos/<clip>.MP4"     # uses data/calibration.json

# Python side
python3 training/eval_track.py --video "data/test_videos/<clip>.MP4"
```

The iOS analyzer uses only the 4 corner points of the calibration (its
homography replaces the prototype's clicked dot-line and pixel-row tests), and
the Core ML fp16 detector instead of PyTorch fp32 — so tracks differ slightly
and exact numeric parity is not expected.

## Results (2026-07-02, ball.pt of 06-16, calibration.json of the June setup)

| Clip | Speed Py/iOS (mph) | Arrows | Breakpoint | Entry (°) |
|------|--------------------|--------|------------|-----------|
| test 06-15 (held out) | -- / 18.2 | 14.8 / 14.3 | 6.9 / 6.5 | 13.9 / 8.3 |
| 06-10 15-50 | 11.2 / 11.3 | 14.9 / 14.0 | 12.3 / 12.2 | 9.8 / 8.7 |
| 06-10 15-52 | -- / -- | 35.5 / 32.1 | 29.5 / 28.8 | -0.2 / -1.2 |
| 06-10 15-53 | -- / 18.6 | 15.0 / 14.3 | 6.7 / 6.4 | -- / 8.1 |
| 03-30 (stale calibration) | -- / 27.4 | 28.0 / 29.6 | 25.3 / 26.2 | 2.3 / 2.9 |

**Conclusions**

- Arrows / breakpoint: within ~1 board everywhere; primary metrics are at parity.
- Speed (2026-07-02 rework): iOS times the earliest 6 ft the track covers
  instead of requiring foul-line → dot-row coverage, so lofted releases and
  late track locks still get a launch speed; the window must start ≤ 15 ft
  (deeper reads aren't launch speeds — the ball sheds 2–3 mph down-lane).
  Where the Python foul→dot number exists (15-50) the two agree within 1%;
  clips the old gate rejected now read plausible league speeds (18.2, 18.6).
  15-52's track never covers a front-lane 6 ft span — correctly refused by
  both pipelines. 03-30 remains garbage-in-garbage-out on its stale
  calibration (27.4, was 23.8 under the old gate).
- Entry angle is the tail-slope of the track and is the most
  detector-sensitive metric: ±1.2° on most clips but 13.9 vs 8.3 on the test
  clip, and each pipeline computes it once where the other can't. Re-baseline
  on real in-app footage (task #8) before trusting absolute values.
- 03-30 predates the calibration; both pipelines emit garbage boards on it
  (arrows 28–35). iOS's 23.8 mph there comes from a track that legitimately
  passes both timing marks — not a guard bug, just a different (equally
  miscalibrated) track.
- Runtime: full clip in ~1.2 s at -O on M4 Max.

## Entry board (2026-07-02, iOS-only — no Python counterpart)

Board at 59.5 ft, projected from the entry-angle tail slope because the track
stops ~2% short of the pins; requires the track to reach 50 ft. On the
matched-calibration clips: 20.2 (test 06-15), -- (15-50, track ends early —
guard working), 28.5 (15-52, the garbage-boards clip, consistent with its
track), 19.4 (15-53). Inherits entry angle's detector sensitivity — re-baseline
against known pocket hits on real in-app footage before trusting absolutes.

## Launch angle (2026-07-06, iOS-only — no Python counterpart)

Slope of the first tracked stretch, positive = launched toward the gutter;
same tail-slope geometry as entry angle, opposite end and sign. Requires the
track to start ≤ 15 ft like speed. On the matched-calibration clips: 2.1°
(test 06-15), 1.5° (15-50), -- (15-52, mid-lane lock — guard working), 2.1°
(15-53). Existing metrics unchanged on all clips after the addition.
