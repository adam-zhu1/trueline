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
    /// True when arriving fresh from an analysis: the content plays its
    /// entrance choreography (line draws in, tiles land). History opens
    /// with everything already in place.
    var reveal = false
    var onDone: () -> Void

    @Environment(TruelineStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @AppStorage("saveShotVideos") private var saveShotVideos = true
    /// Sticky across throws and launches — league bowlers throw the same ball
    /// all night, so the tag should survive without a tap.
    @AppStorage("lastBall") private var selectedBall = ""
    @State private var newBallName = ""
    @State private var askNewBall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ShotResultContent(result: result, clipURL: clipURL, targetBoard: targetBoard, reveal: reveal)
                    .padding()
            }
            .navigationTitle("Shot Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShotShareButton(result: result, date: .now, tags: sessionTags)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack {
                        ballMenu
                        Spacer()
                        if !store.isUnlocked {
                            // Keep the limit visible from throw one — the gate
                            // should never feel like an ambush.
                            Text("\(store.freeThrowsLeft) of \(TruelineStore.freeThrowLimit) free throws left")
                                .font(.footnote)
                                .foregroundStyle(store.freeThrowsLeft <= 2 ? Color.brandMint : .secondary)
                        }
                    }
                    resultButtons
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .alert("Ball name", isPresented: $askNewBall) {
                TextField("e.g. Phaze II", text: $newBallName)
                Button("Add") {
                    selectedBall = newBallName.trimmingCharacters(in: .whitespaces)
                    newBallName = ""
                }
                Button("Cancel", role: .cancel) { newBallName = "" }
            } message: {
                Text("Tag this shot's ball to compare equipment in Stats.")
            }
        }
    }

    /// Quick ball tag: recent balls one tap away, new ones by name. Stored on
    /// the shot at save time (and onto an untagged session), which is how
    /// imported one-offs make it into per-ball stats.
    private var ballMenu: some View {
        Menu {
            ForEach(RecentBalls.load(), id: \.self) { ball in
                Button(ball) { selectedBall = ball }
            }
            Divider()
            Button("New Ball…") { askNewBall = true }
            if !selectedBall.isEmpty {
                Button("No Ball") { selectedBall = "" }
            }
        } label: {
            Label(selectedBall.isEmpty ? "Tag Ball" : selectedBall, systemImage: "circle.circle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(selectedBall.isEmpty ? Color.secondary : Color.brandMint)
        }
    }

    private var resultButtons: some View {
        HStack(spacing: 12) {
            Button("Discard") { onDone() }
                .buttonStyle(.secondaryAction)
                .frame(maxWidth: 130)
            Button {
                let shot = SavedShot(result: result)
                shot.session = session
                shot.ball = selectedBall
                RecentBalls.noteUsed(selectedBall)
                // A live session inherits the first tagged ball so its
                // detail screen and tags line stay populated.
                if let session, session.ball.isEmpty {
                    session.ball = selectedBall
                }
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
    }

    private var sessionTags: [String] {
        guard let session else {
            return selectedBall.isEmpty ? [] : [selectedBall]
        }
        return [session.ball, session.center, session.oilPattern].filter { !$0.isEmpty }
    }
}

/// Runs the analyzer over the clip with a progress bar, then hands the result up.
struct AnalysisView: View {
    let clipURL: URL
    let corners: LaneCorners
    var onComplete: (ShotResult) -> Void
    var onFailed: () -> Void
    /// Present when the flow offers a way back out mid-analysis (a long
    /// imported clip shouldn't trap the user on a progress screen).
    var onCancel: (() -> Void)? = nil

    /// One detector per process. The Core ML load is the slow part and used to
    /// run synchronously on the main actor, freezing the UI at the start of
    /// every analysis — now it happens once, off the main actor, and every
    /// later throw in a session reuses it.
    private static let detectorTask = Task.detached(priority: .userInitiated) {
        try BallDetector(model: ball(configuration: MLModelConfiguration()).model)
    }

    @AppStorage("bowlingHand") private var bowlingHand = "right"
    @State private var progress = 0.0
    @State private var livePoints: [CGPoint] = []
    @State private var counterDone = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AnalysisProgressView(
                progress: progress,
                livePath: livePoints,
                onCountedToFull: { counterDone = true },
                onCancel: onCancel
            )
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
                } livePath: { points in
                    Task { @MainActor in livePoints = points }
                }
                // Let the counter finish its climb to 100 (it smooths real
                // progress and enforces a minimum run), hold a beat, then
                // hand off — the parent wipes this screen up like a curtain.
                progress = 1
                while !counterDone {
                    try? await Task.sleep(for: .milliseconds(40))
                }
                try? await Task.sleep(for: .milliseconds(300))
                onComplete(result)
            } catch is CancellationError {
                // The user backed out; the flow already navigated away.
            } catch {
                onFailed()
            }
        }
    }
}
