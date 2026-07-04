import SwiftUI

/// Branded cold-start moment: the mint ball skids down-lane, hooks into the
/// pocket, and strikes — pin burst, then the wordmark lands. Research-backed
/// constraints: one motion, ~1.5 s, tap to skip, no artificial loading — the
/// app behind it is already ready. Reduce Motion gets a static wordmark.
struct LaunchAnimationView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var finished = false

    private let rollDuration = 0.85
    private let impactDuration = 0.55

    /// Deterministic pin-burst directions (unit vectors, biased upward like
    /// pins leaving the deck) and per-particle speed.
    private static let burst: [(dx: Double, dy: Double, speed: Double, mint: Bool)] = [
        (-0.90, -0.44, 52, false), (-0.55, -0.83, 62, true), (-0.20, -0.98, 70, false),
        (0.18, -0.99, 66, false), (0.52, -0.85, 60, true), (0.88, -0.47, 54, false),
        (-0.70, 0.10, 40, false), (0.68, 0.14, 42, false),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if reduceMotion {
                wordmark(reveal: 1, pop: 0)
            } else {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let t = min(max(elapsed / rollDuration, 0), 1)
                    // Ease-out: fast off the hand, settling into the pocket.
                    let u = 1 - pow(1 - t, 1.7)
                    let impact = min(max((elapsed - rollDuration) / impactDuration, 0), 1)

                    ZStack {
                        Canvas { ctx, size in
                            let region = CGRect(
                                x: size.width * 0.28,
                                y: size.height * 0.16,
                                width: size.width * 0.44,
                                height: size.height * 0.44
                            )
                            drawTrail(ctx, u: u, impact: impact, region: region)
                            if impact > 0 {
                                drawStrike(ctx, at: HookCurve.point(at: 1, in: region), impact: impact)
                            }
                            if impact < 0.5 {
                                drawBall(ctx, at: HookCurve.point(at: u, in: region), fade: impact / 0.5)
                            }
                        }
                        wordmark(
                            reveal: min(max((t - 0.7) / 0.3, 0), 1),
                            pop: impact
                        )
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : rollDuration + impactDuration + 0.15))
            finish()
        }
    }

    /// Comet trail: short segments that fade and thin toward the tail, plus a
    /// soft glow pass under the head.
    private func drawTrail(_ ctx: GraphicsContext, u: Double, impact: Double, region: CGRect) {
        guard u > 0.01 else { return }
        let steps = 64
        let trailFade = 1.0 - 0.65 * impact
        var prev = HookCurve.point(at: 0, in: region)
        for i in 1...steps {
            let s = u * Double(i) / Double(steps)
            let pt = HookCurve.point(at: s, in: region)
            let a = Double(i) / Double(steps)
            var seg = Path()
            seg.move(to: prev)
            seg.addLine(to: pt)
            // Butt caps: round caps on contiguous segments stack opacity at
            // every joint and the trail reads as beads.
            ctx.stroke(
                seg,
                with: .color(.brandMint.opacity(pow(a, 2.2) * 0.85 * trailFade)),
                style: StrokeStyle(lineWidth: 1.5 + 3.0 * a, lineCap: .butt)
            )
            // Glow pass on the leading quarter of the trail.
            if a > 0.75 {
                ctx.stroke(
                    seg,
                    with: .color(.brandMint.opacity((a - 0.75) * 0.5 * trailFade)),
                    style: StrokeStyle(lineWidth: 9, lineCap: .butt)
                )
            }
            prev = pt
        }
    }

    private func drawBall(_ ctx: GraphicsContext, at pt: CGPoint, fade: Double) {
        let alpha = 1.0 - fade
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 17, y: pt.y - 17, width: 34, height: 34)),
            with: .color(.brandMint.opacity(0.25 * alpha))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 8.5, y: pt.y - 8.5, width: 17, height: 17)),
            with: .color(.brandMint.opacity(alpha))
        )
    }

    /// The strike: an expanding ring and pin-white particles thrown off the
    /// deck, all easing out and fading over the impact beat.
    private func drawStrike(_ ctx: GraphicsContext, at pt: CGPoint, impact: Double) {
        let ease = 1 - pow(1 - impact, 2.2)
        let fade = 1 - impact

        let ringR = 10 + 46 * ease
        ctx.stroke(
            Path(ellipseIn: CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2)),
            with: .color(.brandMint.opacity(0.55 * fade)),
            lineWidth: 2.5 * fade + 0.5
        )

        for p in Self.burst {
            let px = pt.x + p.dx * p.speed * ease
            let py = pt.y + p.dy * p.speed * ease
            let r = 3.2 * (1 - 0.5 * impact)
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                with: .color((p.mint ? Color.brandMint : Color(white: 0.92)).opacity(fade))
            )
        }
    }

    private func wordmark(reveal: Double, pop: Double) -> some View {
        // A quick pulse as the ball strikes, then settle.
        let popScale = 1 + 0.07 * sin(min(pop, 0.4) / 0.4 * .pi)
        return VStack {
            Spacer()
            (Text("True").foregroundStyle(.white) + Text("Line").foregroundStyle(Color.brandMint))
                .font(.system(size: 40, weight: .bold))
                .opacity(reveal)
                .scaleEffect((0.94 + 0.06 * reveal) * popScale)
                .padding(.bottom, 120)
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

#Preview {
    LaunchAnimationView {}
}
