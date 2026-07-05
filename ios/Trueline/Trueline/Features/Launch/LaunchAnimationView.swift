import SwiftUI

/// Branded cold-start moment: the wordmark cascades in letter by letter, the
/// ball rolls beneath it drawing the brand's underline, and strikes a mini
/// pin rack at the end — scattered pins, sparks, ring, impact pop. One scene
/// on black, ~1.7 s, tap to skip, no artificial loading — the app behind it
/// is already ready. Reduce Motion gets a static wordmark instead.
struct LaunchAnimationView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var finished = false

    private static let word = Array("TrueLine")
    /// "Line" — the mint half of the wordmark — starts here.
    private static let mintFrom = 4

    // Timeline, seconds from start: letters cascade, then the ball rolls the
    // underline, then the strike.
    private let letterStagger = 0.05
    private let letterDuration = 0.22
    private let rollStart = 0.45
    private let rollDuration = 0.6
    private let impactDuration = 0.55
    private var impactStart: Double { rollStart + rollDuration }
    private var totalDuration: Double { impactStart + impactDuration + 0.1 }

    /// Pin scatter on impact: direction and travel per pin (deterministic —
    /// the strike looks identical every launch).
    private static let pinScatter: [(dx: Double, dy: Double, dist: Double)] = [
        (0.35, -1.0, 64), (1.0, -0.55, 74), (0.75, -1.25, 58),
    ]
    /// Extra sparks thrown off the deck.
    private static let sparks: [(dx: Double, dy: Double, dist: Double, mint: Bool)] = [
        (-0.6, -0.8, 44, true), (-0.15, -1.0, 54, false), (0.3, -0.95, 48, true),
        (0.9, -0.25, 42, false), (0.55, -0.7, 58, true),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if reduceMotion {
                staticWordmark
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSince(startDate)
                    Canvas { ctx, size in
                        draw(ctx, size: size, t: t)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : totalDuration))
            finish()
        }
    }

    private var staticWordmark: some View {
        (Text("True").foregroundStyle(.white) + Text("Line").foregroundStyle(Color.brandMint))
            .font(.system(size: 44, weight: .bold))
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let letters = Self.word.indices.map { i in
            ctx.resolve(
                Text(String(Self.word[i]))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(i >= Self.mintFrom ? Color.brandMint : Color.white)
            )
        }
        let sizes = letters.map { $0.measure(in: CGSize(width: 200, height: 120)) }
        let totalWidth = sizes.reduce(0) { $0 + $1.width }
        let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
        let startX = center.x - totalWidth / 2

        let roll = clamp((t - rollStart) / rollDuration)
        let impact = clamp((t - impactStart) / impactDuration)

        // Wordmark: letters drop in with a stagger; the whole word pulses
        // once as the ball strikes.
        let pop = 1 + 0.06 * sin(clamp(impact / 0.4) * .pi)
        var textLayer = ctx
        textLayer.translateBy(x: center.x, y: center.y)
        textLayer.scaleBy(x: pop, y: pop)
        textLayer.translateBy(x: -center.x, y: -center.y)
        var penX = startX
        for (i, letter) in letters.enumerated() {
            let reveal = clamp((t - Double(i) * letterStagger) / letterDuration)
            let eased = 1 - pow(1 - reveal, 2.0)
            var layer = textLayer
            layer.opacity = reveal
            layer.draw(letter, at: CGPoint(
                x: penX + sizes[i].width / 2,
                y: center.y + (1 - eased) * 16
            ))
            penX += sizes[i].width
        }

        // The underline the ball draws, and the rack it runs into.
        let lineY = center.y + (sizes.first?.height ?? 44) / 2 + 12
        let lineStart = startX
        let lineEnd = startX + totalWidth
        let rollEased = roll * roll * (3 - 2 * roll)
        let ballX = lineStart + (lineEnd - lineStart) * rollEased
        let pinBase = CGPoint(x: lineEnd + 15, y: lineY - 4)

        // Mini rack, standing just past the line's end until the strike.
        let pinOffsets: [(Double, Double)] = [(-4.5, 0), (4.5, 0), (0, -8)]
        if impact <= 0 {
            let standOpacity = clamp(roll * 3)
            for (dx, dy) in pinOffsets {
                pin(ctx, at: CGPoint(x: pinBase.x + dx, y: pinBase.y + dy), opacity: standOpacity)
            }
        }

        if roll > 0 {
            // Comet underline while rolling; once drawn it stays — the ball
            // just wrote the "Line" in TrueLine.
            if roll < 1 {
                let steps = 40
                for i in 1...steps {
                    let a = Double(i) / Double(steps)
                    var seg = Path()
                    seg.move(to: CGPoint(x: lineStart + (ballX - lineStart) * (a - 1.0 / Double(steps)), y: lineY))
                    seg.addLine(to: CGPoint(x: lineStart + (ballX - lineStart) * a, y: lineY))
                    ctx.stroke(
                        seg,
                        with: .color(.brandMint.opacity(0.25 + 0.65 * a)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .butt)
                    )
                }
            } else {
                var line = Path()
                line.move(to: CGPoint(x: lineStart, y: lineY))
                line.addLine(to: CGPoint(x: lineEnd, y: lineY))
                ctx.stroke(line, with: .color(.brandMint), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            // The ball: glowing head while rolling, gone in the strike flash.
            if impact < 0.35 {
                let alpha = 1 - impact / 0.35
                let ballPos = CGPoint(x: min(ballX, pinBase.x - 6), y: lineY - 7)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: ballPos.x - 14, y: ballPos.y - 14, width: 28, height: 28)),
                    with: .color(.brandMint.opacity(0.28 * alpha))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: ballPos.x - 7, y: ballPos.y - 7, width: 14, height: 14)),
                    with: .color(.brandMint.opacity(alpha))
                )
            }
        }

        // The strike: pins scatter in arcs, sparks fly, a ring expands.
        if impact > 0 {
            let ease = 1 - pow(1 - impact, 2.2)
            let fade = 1 - impact

            for (i, (dx, dy)) in pinOffsets.enumerated() {
                let s = Self.pinScatter[i]
                let px = pinBase.x + dx + s.dx * s.dist * ease
                let py = pinBase.y + dy + s.dy * s.dist * ease + 34 * ease * ease
                pin(ctx, at: CGPoint(x: px, y: py), opacity: fade)
            }

            for s in Self.sparks {
                let px = pinBase.x + s.dx * s.dist * ease
                let py = pinBase.y + s.dy * s.dist * ease + 22 * ease * ease
                let r = 2.6 * (1 - 0.5 * impact)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                    with: .color((s.mint ? Color.brandMint : Color(white: 0.92)).opacity(fade))
                )
            }

            let ringR = 8 + 40 * ease
            ctx.stroke(
                Path(ellipseIn: CGRect(
                    x: pinBase.x - ringR, y: pinBase.y - ringR,
                    width: ringR * 2, height: ringR * 2
                )),
                with: .color(.brandMint.opacity(0.55 * fade)),
                lineWidth: 2.5 * fade + 0.5
            )
        }
    }

    private func pin(_ ctx: GraphicsContext, at pt: CGPoint, opacity: Double) {
        let r = 3.4
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
            with: .color(Color(white: 0.92).opacity(opacity))
        )
    }

    private func clamp(_ v: Double) -> Double {
        min(max(v, 0), 1)
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
