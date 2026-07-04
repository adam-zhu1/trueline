import AVKit
import CoreML
import SwiftData
import SwiftUI

/// Shot results: the throw video with the tracked path drawn on it, a compact
/// lane diagram alongside, and the four core metrics below.
struct ResultsView: View {
    let clipURL: URL
    let result: ShotResult
    var session: BowlingSession?
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("speedUnit") private var speedUnit = "mph"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if result.videoDisplaySize.height >= result.videoDisplaySize.width {
                        // Portrait clip: video dominant, thin lane view beside it,
                        // heights matched to a share of the screen so small
                        // phones still see the metrics without scrolling far.
                        HStack(spacing: 12) {
                            VideoPathView(clipURL: clipURL, result: result)
                            LaneViewCanvas(result: result, compact: true)
                                .frame(width: 104)
                        }
                        .containerRelativeFrame(.vertical) { length, _ in length * 0.52 }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Landscape clip: no room beside it — stack instead.
                        VideoPathView(clipURL: clipURL, result: result)
                        LaneViewCanvas(result: result, compact: true)
                            .frame(height: 320)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(
                            title: "Speed",
                            value: format(result.speedMph.map { SpeedUnit.value($0, unit: speedUnit) }),
                            unit: SpeedUnit.label(speedUnit)
                        )
                        MetricTile(title: "Board at Arrows", value: format(result.arrowBoard), unit: "board")
                        MetricTile(
                            title: "Entry Board", value: format(result.entryBoard), unit: "board",
                            numeric: result.entryBoard, ideal: 17...18
                        )
                        MetricTile(
                            title: "Entry Angle", value: format(result.entryAngleDegrees), unit: "°",
                            numeric: result.entryAngleDegrees, ideal: 4...6
                        )
                        MetricTile(title: "Breakpoint", value: format(result.breakpointBoard), unit: "board")
                        MetricTile(
                            title: "Breakpoint Distance",
                            value: result.breakpointFeet.map { String(format: "%.0f", $0) } ?? "--",
                            unit: "ft"
                        )
                    }

                    if result.speedMph == nil {
                        Text("Speed needs the ball tracked through the front of the lane — start recording before the throw.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
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
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button("Discard") { onDone() }
                        .buttonStyle(.secondaryAction)
                        .frame(maxWidth: 130)
                    Button {
                        let shot = SavedShot(result: result)
                        shot.session = session
                        modelContext.insert(shot)
                        onDone()
                    } label: {
                        Label("Save Shot", systemImage: "checkmark")
                    }
                    .buttonStyle(.primaryAction)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}

/// Runs the analyzer over the clip with a progress bar, then hands the result up.
struct AnalysisView: View {
    let clipURL: URL
    let corners: LaneCorners
    var onComplete: (ShotResult) -> Void
    var onFailed: () -> Void

    /// One detector per process. The Core ML load is the slow part and used to
    /// run synchronously on the main actor, freezing the UI at the start of
    /// every analysis — now it happens once, off the main actor, and every
    /// later throw in a session reuses it.
    private static let detectorTask = Task.detached(priority: .userInitiated) {
        try BallDetector(model: ball(configuration: MLModelConfiguration()).model)
    }

    @AppStorage("bowlingHand") private var bowlingHand = "right"
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AnalysisProgressView(progress: progress)
        }
        .task {
            do {
                let analyzer = ShotAnalyzer(
                    detector: try await Self.detectorTask.value,
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
