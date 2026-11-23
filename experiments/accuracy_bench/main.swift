// Accuracy benchmark runner: the app's ShotAnalyzer (the exact sources the
// app compiles) over every clip in a manifest, one JSON result per clip with
// the metrics, the gate counts and the per-sample trace. bench.py builds the
// manifest, runs this, and scores the output against the labels.
//
// Build & run (repo root):
//   swiftc -O -o /tmp/accbench experiments/accuracy_bench/main.swift \
//     ios/Trueline/Trueline/Analysis/*.swift ios/Trueline/Trueline/Models/LaneCorners.swift
//   /tmp/accbench manifest.json out.json [model.mlpackage]

import AVFoundation
import CoreML
import Foundation

struct ManifestClip: Decodable {
    let id: String
    let video: String
    let hand: String
    /// Display-oriented pixel corners, app convention.
    let farLeft: [Double]
    let farRight: [Double]
    let nearRight: [Double]
    let nearLeft: [Double]
}

struct ClipOutput: Encodable {
    let id: String
    let video: String
    let error: String?
    let displayWidth: Double
    let displayHeight: Double
    let speedMph: Double?
    let averageSpeedMph: Double?
    let arrowBoard: Double?
    let breakpointBoard: Double?
    let breakpointFeet: Double?
    let entryAngleDegrees: Double?
    let entryBoard: Double?
    let launchAngleDegrees: Double?
    let foulLineBoard: Double?
    let trackedFrames: Int
    let reliable: Bool
    let failure: String?
    let path: [[Double]]
    let trace: AnalysisTrace?
    let seconds: Double
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: accbench <manifest.json> <out.json> [model.mlpackage]")
    exit(1)
}
let clips = try JSONDecoder().decode(
    [ManifestClip].self, from: Data(contentsOf: URL(fileURLWithPath: args[1]))
)
let modelPath = args.count > 3 ? args[3] : "ios/Trueline/Trueline/ML/ball.mlpackage"
let compiledURL = try await MLModel.compileModel(at: URL(fileURLWithPath: modelPath))
let model = try MLModel(contentsOf: compiledURL)

var outputs: [ClipOutput] = []
for clip in clips {
    let url = URL(fileURLWithPath: clip.video)
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        print("\(clip.id): no video track")
        continue
    }
    let natural = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let display = natural.applying(transform)
    let w = abs(Double(display.width)), h = abs(Double(display.height))
    func norm(_ p: [Double]) -> CGPoint { CGPoint(x: p[0] / w, y: p[1] / h) }
    let corners = LaneCorners(
        farLeft: norm(clip.farLeft), farRight: norm(clip.farRight),
        nearRight: norm(clip.nearRight), nearLeft: norm(clip.nearLeft)
    )
    let analyzer = ShotAnalyzer(
        detector: try BallDetector(model: model),
        corners: corners,
        hand: clip.hand == "L" ? .left : .right
    )
    let start = Date()
    do {
        let r = try await analyzer.analyze(videoURL: url)
        let secs = Date().timeIntervalSince(start)
        outputs.append(ClipOutput(
            id: clip.id, video: clip.video, error: nil, displayWidth: w, displayHeight: h,
            speedMph: r.speedMph, averageSpeedMph: r.averageSpeedMph,
            arrowBoard: r.arrowBoard, breakpointBoard: r.breakpointBoard,
            breakpointFeet: r.breakpointFeet, entryAngleDegrees: r.entryAngleDegrees,
            entryBoard: r.entryBoard, launchAngleDegrees: r.launchAngleDegrees,
            foulLineBoard: r.foulLineBoard, trackedFrames: r.trackedFrames,
            reliable: r.isReliable, failure: r.failure.map { "\($0)" },
            path: r.path.map { [$0.board, $0.feet] }, trace: r.trace, seconds: secs
        ))
        let e = r.entryBoard.map { String(format: "%.1f", $0) } ?? "--"
        let last = r.trace?.samples.last?.feet ?? 0
        print(String(format: "%@: %d tracked, to %.1f ft, entry %@ (%.1fs)",
                     clip.id, r.trackedFrames, last, e, secs))
    } catch {
        outputs.append(ClipOutput(
            id: clip.id, video: clip.video, error: "\(error)", displayWidth: w, displayHeight: h,
            speedMph: nil, averageSpeedMph: nil, arrowBoard: nil, breakpointBoard: nil,
            breakpointFeet: nil, entryAngleDegrees: nil, entryBoard: nil,
            launchAngleDegrees: nil, foulLineBoard: nil, trackedFrames: 0, reliable: false,
            failure: nil, path: [], trace: nil, seconds: 0
        ))
        print("\(clip.id): ERROR \(error)")
    }
}
let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys]
try enc.encode(outputs).write(to: URL(fileURLWithPath: args[2]))
