import AVFoundation
import SwiftUI

@main
struct TruelineApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
                if let demoURL = Self.calibrationDemoURL {
                    DemoAnalysisFlow(clipURL: demoURL)
                } else {
                    ContentView()
                }
            }
            .modelContainer(for: SavedShot.self)
        }
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
                ResultsView(clipURL: clipURL, result: result) {}
            } else if let corners {
                AnalysisView(
                    clipURL: clipURL,
                    corners: corners,
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
