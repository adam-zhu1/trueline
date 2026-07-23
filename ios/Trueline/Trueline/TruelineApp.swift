import AVFoundation
import SwiftData
import SwiftUI

@main
struct TruelineApp: App {
    @State private var store = TruelineStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let progress = Self.progressPreviewValue {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        if progress > 1 {
                            AnimatedProgressPreview()
                        } else {
                            AnalysisProgressView(progress: progress)
                        }
                    }
                } else if let demoURL = Self.calibrationDemoURL {
                    DemoAnalysisFlow(clipURL: demoURL)
                } else if Self.shareCardPreview {
                    #if DEBUG
                    ShareCardPreview()
                    #endif
                } else if Self.paywallPreview {
                    #if DEBUG
                    PaywallView {}
                    #endif
                } else if Self.trendsPreview {
                    #if DEBUG
                    TrendsPreview()
                    #endif
                } else if Self.sessionDetailPreview {
                    #if DEBUG
                    SessionDetailPreview()
                    #endif
                } else {
                    ContentView()
                }
            }
            .modelContainer(for: SavedShot.self)
            .environment(store)
            .task { await store.start() }
        }
    }

    /// Debug hook: launch with `-paywallPreview` to open straight onto the
    /// purchase screen (with `-freeThrowsUsed 10` for the out-of-throws copy).
    private static var paywallPreview: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "paywallPreview")
        #else
        false
        #endif
    }

    /// Debug hooks: `-trendsPreview` / `-sessionDetailPreview` (with
    /// `-seedDemoHistory`) open straight onto those screens — they live behind
    /// History navigation the CLI can't tap through.
    private static var trendsPreview: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "trendsPreview")
        #else
        false
        #endif
    }

    private static var sessionDetailPreview: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "sessionDetailPreview")
        #else
        false
        #endif
    }

    /// Debug hook: launch with `-progressPreview <0–1>` to pin the analysis
    /// progress view at a fixed value — the real analysis is too fast in the
    /// simulator to inspect visually. A value above 1 ramps 0→1 over a few
    /// seconds instead, which is the only way to see the strike finish (it
    /// fires on the transition to 1, so a pinned value never triggers it).
    /// Above 1 rather than negative because the launch-argument parser eats
    /// a leading "-" on the value.
    private static var progressPreviewValue: Double? {
        #if DEBUG
        UserDefaults.standard.object(forKey: "progressPreview")
            .map { _ in UserDefaults.standard.double(forKey: "progressPreview") }
        #else
        nil
        #endif
    }

    /// Debug hook: launch with `-shareCardPreview` to show the share card with
    /// sample data — the card is only ever rendered off-screen in production,
    /// so this is the way to eyeball it in the simulator.
    private static var shareCardPreview: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "shareCardPreview")
        #else
        false
        #endif
    }

    /// Debug hook: launch with `-calibrationDemo <path>` to run the real
    /// calibrate → analyze → results sequence on a local clip — lets the
    /// simulator (no camera) exercise the whole pipeline.
    private static var calibrationDemoURL: URL? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "calibrationDemo")
            .map(URL.init(fileURLWithPath:))
        #else
        nil
        #endif
    }
}

#if DEBUG
/// Ramps analysis progress 0→1 with a synthetic tracked path arriving partway
/// through — every stage (looking, tracking, measuring captions and the hook
/// loop) can be watched and screenshotted without running a real analysis.
/// The path mimics a real stream: points appear only while "the throw" is on
/// screen.
private struct AnimatedProgressPreview: View {
    @State private var progress = 0.0
    @State private var points: [CGPoint] = []

    var body: some View {
        AnalysisProgressView(progress: progress, livePath: points)
            .task {
                while progress < 1 {
                    try? await Task.sleep(for: .milliseconds(40))
                    progress = min(progress + 0.008, 1)
                    // The ball shows up a third of the way into the clip.
                    let t = (progress - 0.35) / 0.55
                    if t > 0 {
                        let u = min(t, 1)
                        points.append(CGPoint(
                            x: 0.62 - 0.30 * u + 0.16 * u * u,
                            y: 0.92 - 0.80 * u
                        ))
                    }
                }
            }
    }
}

/// Stats over the seeded demo history — the same data every run. Add
/// `-trendsPreviewBottom` to open scrolled to the end (the CLI can't swipe).
private struct TrendsPreview: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        StatsView()
            .defaultScrollAnchor(
                UserDefaults.standard.bool(forKey: "trendsPreviewBottom") ? .bottom : .top
            )
            .preferredColorScheme(.dark)
            .onAppear { DemoSeed.seedIfRequested(context: modelContext) }
    }
}

/// A seeded session's detail screen (consistency rows, lines overlay).
private struct SessionDetailPreview: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BowlingSession.date, order: .reverse) private var sessions: [BowlingSession]

    var body: some View {
        NavigationStack {
            if let session = sessions.first(where: { !$0.shots.isEmpty }) {
                SessionDetailView(session: session)
            } else {
                ProgressView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { DemoSeed.seedIfRequested(context: modelContext) }
    }
}

/// Shows the ImageRenderer output — the exact bitmap the share sheet gets —
/// not the live view, so a screenshot verifies the real share pipeline.
private struct ShareCardPreview: View {
    @State private var card: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let card {
                Image(uiImage: card)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        }
        .onAppear {
            let renderer = ImageRenderer(content: ShareCardView(
                result: .sampleCard,
                date: .now,
                tags: ["Phaze II", "Kingpin Lanes", "House"]
            ))
            renderer.scale = 3
            card = renderer.uiImage
        }
    }
}

/// Auto-advances through the pipeline (no taps — the simulator can't be tapped
/// from the CLI): auto-detect corners on the first frame, analyze, show results.
private struct DemoAnalysisFlow: View {
    let clipURL: URL
    @State private var corners: LaneCorners?
    @State private var result: ShotResult?
    @State private var failed = false

    var body: some View {
        Group {
            if failed {
                Text("Demo failed").foregroundStyle(.red)
            } else if let result {
                ResultsView(clipURL: clipURL, result: result, session: nil, reveal: true) {}
            } else if let corners {
                AnalysisView(
                    clipURL: clipURL,
                    corners: corners,
                    // Instant swap — ResultsView(reveal:) runs the curtain.
                    onComplete: { result = $0 },
                    onFailed: { failed = true }
                )
            } else {
                ProgressView("Detecting lane…")
            }
        }
        .task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clipURL))
            generator.appliesPreferredTrackTransform = true
            guard let (cgImage, _) = try? await generator.image(at: .zero) else {
                failed = true
                return
            }
            corners = LaneAutoDetector.detectLaneCorners(in: cgImage) ?? .defaultGuess
        }
    }
}
#endif
