import SwiftUI

/// The analysis wait as an editorial preloader: typography only. Wordmark and
/// "Shot analysis" hold the top corners; a lowercase stage caption and a huge
/// percent counter hold the bottom. The counter is the design — it tracks
/// real progress but is smoothed (and given a minimum run time) so it never
/// jumps, and finishes with a slow crawl into 100. When it lands, the parent
/// wipes this screen up like a curtain onto the result. The caption reacts to
/// the real analysis: it flips from "looking" to "tracking" the moment the
/// tracker first locks onto the ball.
struct AnalysisProgressView: View {
    /// Real progress, 0–1.
    var progress: Double
    /// Tracked path so far. Only its presence is read here — it switches the
    /// caption when the ball is actually found. A snapshot that can shrink
    /// when the tracker drops a false lock, so emptiness can come back.
    var livePath: [CGPoint] = []
    /// Fires once, when the displayed counter completes its climb to 100 —
    /// the cue for the curtain.
    var onCountedToFull: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = 0.0
    @State private var startDate = Date()
    @State private var reportedFull = false

    var body: some View {
        VStack {
            HStack(alignment: .firstTextBaseline) {
                (Text("True").foregroundStyle(.white)
                    + Text("Line").foregroundStyle(Color.brandMint))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("SHOT ANALYSIS")
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.8)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            HStack(alignment: .bottom) {
                Text(stageLabel)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: stageLabel)
                    .padding(.bottom, 18)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int((displayed * 100).rounded()))")
                        .font(.system(size: 104, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.1), value: Int((displayed * 100).rounded()))
                    Text("%")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.brandMint)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque, edge to edge: this screen is the curtain — it must fully
        // cover the result beneath it while it lifts.
        .background(Color.black.ignoresSafeArea())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stageLabel), \(Int((displayed * 100).rounded())) percent")
        .task { await runCounter() }
    }

    private var stageLabel: String {
        if progress >= 1 { return "measuring your line" }
        return livePath.isEmpty ? "looking for the ball" : "tracking the ball"
    }

    /// Smoothed pursuit of real progress: the displayed value chases
    /// min(real, elapsed/minDuration), so fast analyses still get a composed
    /// climb and slow ones never sit at a lie — the counter simply waits for
    /// the real number to catch up.
    private func runCounter() async {
        let minDuration = reduceMotion ? 0.9 : 2.6
        var last = Date()
        while !Task.isCancelled, !reportedFull {
            try? await Task.sleep(for: .milliseconds(33))
            let now = Date()
            let dt = now.timeIntervalSince(last)
            last = now
            let cap = now.timeIntervalSince(startDate) / minDuration
            let target = min(progress, max(cap, 0), 1)
            displayed += (target - displayed) * min(1, dt * 6)
            if target >= 1, displayed > 0.995 { displayed = 1 }
            if displayed >= 1 {
                reportedFull = true
                onCountedToFull?()
            }
        }
    }
}

#Preview("Searching") {
    AnalysisProgressView(progress: 0.18)
}

#Preview("Tracking") {
    AnalysisProgressView(progress: 0.62, livePath: [CGPoint(x: 0.5, y: 0.5)])
}
