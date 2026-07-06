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
    /// Target-line practice target, when the session has one.
    var targetBoard: Double? = nil
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("saveShotVideos") private var saveShotVideos = true

    var body: some View {
        NavigationStack {
            ScrollView {
                ShotResultContent(result: result, clipURL: clipURL, targetBoard: targetBoard)
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
                        if saveShotVideos,
                           let rawName = ShotVideoStore.store(clipURL: clipURL) {
                            // Claim the clip synchronously (move) so the flow's
                            // cleanup can't delete it mid-export, then compact
                            // it in the background: trimmed to the throw and
                            // re-encoded at 720p. Failure keeps the raw.
                            shot.videoFileName = rawName
                            Task {
                                if let compact = await ShotVideoStore.compress(
                                    rawName: rawName,
                                    throwStart: result.throwStartSeconds,
                                    throwEnd: result.throwEndSeconds
                                ) {
                                    shot.videoFileName = compact
                                }
                            }
                        }
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
