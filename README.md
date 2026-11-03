# TrueLine

TrueLine is an iPhone app that tracks a bowling ball from a single phone set up behind the approach. After each throw it shows the ball's path down the lane and the numbers bowlers care about, such as speed, the board at the arrows, the breakpoint and the entry board at the pins. Everything runs on the phone.

[App Store](https://apps.apple.com/app/trueline-bowling-ball-tracker/id6801953797) · [Website](https://adamzhu.dev/trueline/)

## Why I built it

Lane tracking systems like Specto cost thousands of dollars per lane, so most league bowlers never see their own numbers. I wanted the same kind of feedback from a phone. A board is about one inch wide and the lane is sixty feet long, so getting board-level numbers out of phone video is the hard part of the project.

## How it works

1. **Calibration.** The bowler taps six easy landmarks on a still frame: both ends of the foul line, three arrows and the head pin. A least-squares fit turns those taps into a homography from the image to lane coordinates, and the bowler drags a live overlay until the drawn pins sit on the real rack. I chose this flow with a Monte Carlo study on real alley footage, where it cut the median entry-board error from about 3 boards (four corner taps) to under 1.
2. **Detection.** A YOLOv8 model, trained on my own labeled frames and exported to Core ML, finds the ball in each frame. When the ball gets small at the far end of the lane, the detector reruns on a full-resolution crop around where the tracker expects the ball to be.
3. **Tracking.** A Kalman filter links detections into one path and coasts through short gaps. Its timing rules are set in seconds, so 30 and 60 fps recordings behave the same way.
4. **Metrics.** The path is mapped into boards and feet and smoothed, and the metrics are read off it.

## Testing

- `ios/Trueline/TruelineTests` holds unit tests for the lane model, the calibration fit, the contact-point math and the far-lane crop. Run them with Product > Test in Xcode.
- `experiments/shot_parity` compiles the app's analysis code into a command-line tool so it can run on recorded clips on a Mac.
- `experiments/calibration_v11` has the reference calibrations for eight real throws. On the one confirmed pocket strike, the app's entry board is within half a board of the reference (18.0 against 17.6).

## Repo layout

```
ios/Trueline/   the SwiftUI app and its tests
experiments/    calibration study, parity harness, rev rate experiments
training/       detector training scripts
src/            the original Python prototype
docs/           website, privacy and support pages
notes/          planning notes
```

## Status

Version 1.0 is on the App Store. Version 1.1 adds the new calibration, the tracking fixes above and a check that shows if the phone moved between throws. It is waiting on a validation session at the alley before release. Rev rate is in progress as a Python experiment.

## License

MIT. See `LICENSE`.
