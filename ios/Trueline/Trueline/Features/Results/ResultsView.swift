import AVKit
import CoreML
import SwiftData
import SwiftUI

/// Shot results: the throw video with the tracked path drawn on it, a compact
/// lane diagram alongside, and the four core metrics below.
struct ResultsView: View {
    let clipURL: URL
    let result: ShotResult
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var pane: Pane = .video

    private enum Pane {
        case video, lane
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("View", selection: $pane) {
                        Text("Video").tag(Pane.video)
                        Text("Lane View").tag(Pane.lane)
                    }
                    .pickerStyle(.segmented)

                    Group {
                        switch pane {
                        case .video:
                            VideoPathView(clipURL: clipURL, result: result)
                        case .lane:
                            LaneViewCanvas(result: result)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 470)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Speed", value: format(result.speedMph), unit: "mph")
                        MetricTile(title: "Board at Arrows", value: format(result.arrowBoard), unit: "board")
                        MetricTile(title: "Breakpoint", value: format(result.breakpointBoard), unit: "board")
                        MetricTile(title: "Entry Angle", value: format(result.entryAngleDegrees), unit: "°")
                    }

                    if result.trackedFrames < 10 {
                        Text("The ball couldn't be tracked reliably in this clip. Check that the throw is visible and the corners match the lane.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Shot Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(SavedShot(result: result))
                        onDone()
                    }
                    .bold()
                }
            }
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}

/// The source video, looping, with the smoothed ball path drawn on top.
private struct VideoPathView: View {
    let clipURL: URL
    let result: ShotResult

    @State private var player: AVPlayer?
    @State private var looper: Any?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            }
            // The container has the video's aspect ratio, so normalized display
            // coordinates map straight onto the view.
            if result.videoPath.count >= 2 {
                Canvas { context, size in
                    var path = Path()
                    for (i, p) in result.videoPath.enumerated() {
                        let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    context.stroke(
                        path,
                        with: .color(.brandMint),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(
            result.videoDisplaySize.width / max(result.videoDisplaySize.height, 1),
            contentMode: .fit
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            let player = AVPlayer(url: clipURL)
            player.isMuted = true
            self.player = player
            looper = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
            player.play()
        }
        .onDisappear {
            player?.pause()
            if let looper {
                NotificationCenter.default.removeObserver(looper)
            }
        }
    }
}

/// Runs the analyzer over the clip with a progress bar, then hands the result up.
struct AnalysisView: View {
    let clipURL: URL
    let corners: LaneCorners
    var onComplete: (ShotResult) -> Void
    var onFailed: () -> Void

    @AppStorage("bowlingHand") private var bowlingHand = "right"
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .tint(.brandMint)
                    .frame(maxWidth: 240)
                Text("Tracking the ball…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .task {
            do {
                let model = try ball(configuration: MLModelConfiguration()).model
                let analyzer = ShotAnalyzer(
                    detector: try BallDetector(model: model),
                    corners: corners,
                    hand: bowlingHand == "left" ? .left : .right
                )
                let result = try await analyzer.analyze(videoURL: clipURL) { p in
                    Task { @MainActor in progress = p }
                }
                onComplete(result)
            } catch {
                onFailed()
            }
        }
    }
}
