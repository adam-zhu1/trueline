// Parity harness: runs the iOS ShotAnalyzer (the same source files the app
// compiles) on a clip using the corners from a prototype calibration.json, so
// its metrics can be compared with `python3 training/eval_track.py` on
// identical input.
//
// Build & run (repo root):
//   swiftc -O -o /tmp/shotparity experiments/shot_parity/main.swift \
//     ios/Trueline/Trueline/Analysis/*.swift ios/Trueline/Trueline/Models/LaneCorners.swift
//   /tmp/shotparity <video> [calibration.json] [model.mlpackage]

import AVFoundation
import CoreML
import Foundation

struct CalibrationFile: Decodable {
    struct Points: Decodable {
        let foul_line_right: [Double]
        let foul_line_left: [Double]
        let pin_line_right: [Double]
        let pin_line_left: [Double]
    }
    let points: Points
    let bowler_hand: String
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: shotparity <video> [calibration.json] [model.mlpackage]")
    exit(1)
}
let videoURL = URL(fileURLWithPath: args[1])
let calibPath = args.count > 2 ? args[2] : "data/calibration.json"
let modelPath = args.count > 3 ? args[3] : "models/ball.mlpackage"

let calib = try JSONDecoder().decode(
    CalibrationFile.self, from: Data(contentsOf: URL(fileURLWithPath: calibPath))
)

// Corners are stored in display pixels; LaneCorners wants display-normalized.
let asset = AVURLAsset(url: videoURL)
guard let track = try await asset.loadTracks(withMediaType: .video).first else {
    print("ERROR: no video track")
    exit(1)
}
let naturalSize = try await track.load(.naturalSize)
let transform = try await track.load(.preferredTransform)
let displaySize = naturalSize.applying(transform)
let w = abs(displaySize.width)
let h = abs(displaySize.height)

func norm(_ p: [Double]) -> CGPoint {
    CGPoint(x: p[0] / w, y: p[1] / h)
}
let corners = LaneCorners(
    farLeft: norm(calib.points.pin_line_left),
    farRight: norm(calib.points.pin_line_right),
    nearRight: norm(calib.points.foul_line_right),
    nearLeft: norm(calib.points.foul_line_left)
)

let compiledURL = try await MLModel.compileModel(at: URL(fileURLWithPath: modelPath))
let model = try MLModel(contentsOf: compiledURL)
let analyzer = ShotAnalyzer(
    detector: try BallDetector(model: model),
    corners: corners,
    hand: calib.bowler_hand == "L" ? .left : .right
)

let start = Date()
let result = try await analyzer.analyze(videoURL: videoURL)
let elapsed = Date().timeIntervalSince(start)

func fmt(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "--" }
print("========== iOS SHOT SUMMARY ==========")
print("  Video:            \(videoURL.lastPathComponent)")
print("  Speed:            \(fmt(result.speedMph)) mph")
print("  Board @ arrows:   \(fmt(result.arrowBoard))")
print("  Breakpoint board: \(fmt(result.breakpointBoard))")
print("  Entry angle:      \(fmt(result.entryAngleDegrees))°")
print("  Entry board:      \(fmt(result.entryBoard))")
print("  Launch angle:     \(fmt(result.launchAngleDegrees))°")
print("  Tracked frames:   \(result.trackedFrames)")
print("  Analysis time:    \(String(format: "%.1f", elapsed))s")
print("======================================")
