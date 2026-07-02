import CoreML
import SwiftUI

/// Shot results: lane diagram + the four core metrics.
struct ResultsView: View {
    let result: ShotResult
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LaneViewCanvas(result: result)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
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

    @AppStorage("bowlingHand") private var bowlingHand = "right"
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .tint(.orange)
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
