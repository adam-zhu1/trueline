import SwiftUI

/// The analysis wait keeps to one idea: a mint ball travels the brand hook
/// curve with a short comet trail, breathes out at the pocket, and goes
/// again. The caption underneath reacts to the real analysis — it flips from
/// "looking" to "tracking" the moment the tracker first locks onto the ball —
/// and the percent is real progress, so the wait stays honest without a
/// progress bar. Under Reduce Motion the loop is a still: the full hook line
/// with the ball at the pocket.
struct AnalysisProgressView: View {
    /// Real progress, 0–1.
    var progress: Double
    /// Tracked path so far. Only its presence is read here — it switches the
    /// caption when the ball is actually found. A snapshot that can shrink
    /// when the tracker drops a false lock, so emptiness can come back.
    var livePath: [CGPoint] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 28) {
            if reduceMotion {
                Canvas { context, size in
                    HookLoop.drawStill(context, size: size)
                }
                .frame(width: HookLoop.size.width, height: HookLoop.size.height)
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let phase = t.truncatingRemainder(dividingBy: HookLoop.period)
                            / HookLoop.period
                        HookLoop.draw(context, size: size, at: phase)
                    }
                }
                .frame(width: HookLoop.size.width, height: HookLoop.size.height)
            }

            VStack(spacing: 6) {
                Text(stageLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: stageLabel)
                Text(progress > 0 ? "\(Int((progress * 100).rounded()))%" : " ")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stageLabel) \(Int((progress * 100).rounded())) percent")
    }

    private var stageLabel: String {
        if progress >= 1 { return "Measuring your line…" }
        return livePath.isEmpty ? "Looking for the ball…" : "Tracking the ball…"
    }
}

/// The looping hook: HookCurve traced foul line (bottom) to pocket (top) by a
/// glowing ball with a fading trail. The ball reaches the pocket at 82% of
/// the period; the rest is the whole trace breathing out so the loop restarts
/// clean. Internal (not private) so the debug AnimationLabView can show it
/// beside the candidate replacements.
enum HookLoop {
    static let size = CGSize(width: 170, height: 240)
    static let period: Double = 2.6

    private static let arriveAt = 0.82
    private static let tailLength = 0.45
    private static let ballR: CGFloat = 5.5

    private static func laneRect(in size: CGSize) -> CGRect {
        CGRect(x: 26, y: 14, width: size.width - 52, height: size.height - 28)
    }

    static func draw(_ context: GraphicsContext, size: CGSize, at phase: Double) {
        let rect = laneRect(in: size)
        let travel = min(phase / arriveAt, 1)
        let fade = phase < arriveAt ? 1.0 : 1 - (phase - arriveAt) / (1 - arriveAt)

        if travel > 0.01 {
            let from = max(0, travel - tailLength)
            let steps = 36
            var prev = HookCurve.point(at: from, in: rect)
            for i in 1...steps {
                let a = Double(i) / Double(steps)
                let pt = HookCurve.point(at: from + (travel - from) * a, in: rect)
                var seg = Path()
                seg.move(to: prev)
                seg.addLine(to: pt)
                context.stroke(
                    seg,
                    with: .color(.brandMint.opacity((0.04 + 0.72 * a) * fade)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                prev = pt
            }
        }

        let ball = HookCurve.point(at: travel, in: rect)
        context.fill(
            Path(ellipseIn: CGRect(x: ball.x - 11, y: ball.y - 11, width: 22, height: 22)),
            with: .color(.brandMint.opacity(0.20 * fade))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: ball.x - ballR, y: ball.y - ballR, width: ballR * 2, height: ballR * 2)),
            with: .color(.brandMint.opacity(fade))
        )
    }

    static func drawStill(_ context: GraphicsContext, size: CGSize) {
        let rect = laneRect(in: size)
        var path = Path()
        for step in 0...40 {
            let u = Double(step) / 40
            let pt = HookCurve.point(at: u, in: rect)
            if step == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.stroke(
            path, with: .color(.brandMint.opacity(0.9)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
        let ball = HookCurve.point(at: 1, in: rect)
        context.fill(
            Path(ellipseIn: CGRect(x: ball.x - ballR, y: ball.y - ballR, width: ballR * 2, height: ballR * 2)),
            with: .color(.brandMint)
        )
    }
}

#Preview("Searching") {
    ZStack {
        Color.black.ignoresSafeArea()
        AnalysisProgressView(progress: 0.18)
    }
}

#Preview("Tracking") {
    ZStack {
        Color.black.ignoresSafeArea()
        AnalysisProgressView(
            progress: 0.62,
            livePath: [CGPoint(x: 0.5, y: 0.5)]
        )
    }
}

#Preview("Loop frames") {
    // The loop unrolled, for tuning the trail and breathe-out.
    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
        ForEach([[0.15, 0.4, 0.6], [0.82, 0.9, 0.97]], id: \.self) { row in
            GridRow {
                ForEach(row, id: \.self) { phase in
                    Canvas { context, size in
                        HookLoop.draw(context, size: size, at: phase)
                    }
                    .frame(width: HookLoop.size.width * 0.8, height: HookLoop.size.height * 0.8)
                    .border(.white.opacity(0.15))
                    .overlay(alignment: .topLeading) {
                        Text("\(phase, specifier: "%.2f")")
                            .font(.caption2).foregroundStyle(.secondary).padding(2)
                    }
                }
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
