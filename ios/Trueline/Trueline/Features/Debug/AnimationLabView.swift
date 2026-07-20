#if DEBUG
import SwiftUI

/// Debug-only variant lab for the analysis-wait animation: five candidate
/// concepts side by side, swiped through as pages, each over the real caption
/// and percent so it's judged in context. Launch with `-animationLab`. The
/// point is to react to real motion instead of screenshots — keep the traits
/// that land, cut the rest, then delete this screen once a winner ships.
struct AnimationLabView: View {
    @State private var selection = 0

    private let variants: [(name: String, note: String)] = [
        ("Hook loop", "Current: the brand hook traced by a comet"),
        ("Orbit", "Rev rate: a comet circling — no restart seam"),
        ("Shape morph", "Uber-style: one stroke cycling line → hook → circle"),
        ("Pulse", "Restraint: a breathing dot, nearly nothing"),
        ("Sweep", "A comet passing along a baseline, back and forth"),
        ("Composed", "Same hook loop, but the whole screen designed around it"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(variants.indices, id: \.self) { i in
                    page(i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func page(_ i: Int) -> some View {
        if i == 5 {
            ComposedWaitPage()
        } else {
            plainPage(i)
        }
    }

    private func plainPage(_ i: Int) -> some View {
        VStack(spacing: 0) {
            Text(variants[i].name)
                .font(.headline)
                .foregroundStyle(.white)
            Text(variants[i].note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            variantView(i)
                .frame(width: 220, height: 240)
            VStack(spacing: 6) {
                Text("Tracking the ball…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text("42%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)
            Spacer()
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func variantView(_ i: Int) -> some View {
        switch i {
        case 0:
            TimelineCanvas { ctx, size, t in
                let phase = t.truncatingRemainder(dividingBy: HookLoop.period) / HookLoop.period
                HookLoop.draw(ctx, size: size, at: phase)
            }
        case 1: TimelineCanvas(OrbitVariant.draw)
        case 2: TimelineCanvas(ShapeMorphVariant.draw)
        case 3: TimelineCanvas(PulseVariant.draw)
        default: TimelineCanvas(SweepVariant.draw)
        }
    }
}

/// The completeness test: the same hook loop, but the screen is composed as
/// one designed thing — wordmark anchoring the top, ambient mint depth
/// behind the motion, the percent carrying real typographic weight. If this
/// lands where the bare variants didn't, the problem was never the
/// animation; it was the void around it.
private struct ComposedWaitPage: View {
    var body: some View {
        ZStack {
            // Ambient depth: a faint mint pool behind the animation so the
            // motion sits in a lit space instead of a black void.
            RadialGradient(
                colors: [Color.brandMint.opacity(0.09), .clear],
                center: .center, startRadius: 20, endRadius: 260
            )

            VStack(spacing: 0) {
                (Text("True").foregroundStyle(.white)
                    + Text("Line").foregroundStyle(Color.brandMint))
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 28)

                Spacer()

                TimelineCanvas { ctx, size, t in
                    let phase = t.truncatingRemainder(dividingBy: HookLoop.period)
                        / HookLoop.period
                    HookLoop.draw(ctx, size: size, at: phase)
                }
                .frame(width: 190, height: 250)

                Spacer()

                VStack(spacing: 8) {
                    Text("42%")
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("Tracking the ball…")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 90)
            }
        }
    }
}

/// Shared plumbing: a Canvas redrawn every frame, handed absolute seconds.
private struct TimelineCanvas: View {
    let draw: (GraphicsContext, CGSize, Double) -> Void

    init(_ draw: @escaping (GraphicsContext, CGSize, Double) -> Void) {
        self.draw = draw
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                draw(ctx, size, timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

/// A comet circling clockwise — reads as revolutions. The one loop with no
/// restart moment at all.
private enum OrbitVariant {
    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let period = 1.6
        let phase = t.truncatingRemainder(dividingBy: period) / period
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let r: CGFloat = 54
        let head = phase * 2 * .pi - .pi / 2
        let tail = 2.4
        let steps = 40
        var prev = point(center, r, head - tail)
        for i in 1...steps {
            let a = Double(i) / Double(steps)
            let pt = point(center, r, head - tail * (1 - a))
            var seg = Path()
            seg.move(to: prev)
            seg.addLine(to: pt)
            ctx.stroke(
                seg, with: .color(.brandMint.opacity(0.03 + 0.65 * a)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            prev = pt
        }
        let ball = point(center, r, head)
        ctx.fill(
            Path(ellipseIn: CGRect(x: ball.x - 10, y: ball.y - 10, width: 20, height: 20)),
            with: .color(.brandMint.opacity(0.2))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: ball.x - 5, y: ball.y - 5, width: 10, height: 10)),
            with: .color(.brandMint)
        )
    }

    private static func point(_ c: CGPoint, _ r: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: c.x + r * CGFloat(cos(angle)), y: c.y + r * CGFloat(sin(angle)))
    }
}

/// One continuous mint stroke cycling through the brand's three geometries:
/// the line, the hook, the ball. The closest cousin of Uber's logo morph.
private enum ShapeMorphVariant {
    private static let samples = 64
    private static let hold = 0.6
    private static let morph = 0.8
    private static var leg: Double { hold + morph }
    private static var period: Double { leg * 3 }

    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let phase = t.truncatingRemainder(dividingBy: period)
        let legIndex = min(Int(phase / leg), 2)
        let local = phase - Double(legIndex) * leg
        let f = min(max((local - hold) / morph, 0), 1)
        let m = f * f * (3 - 2 * f)

        let shapes = [linePoints(size), hookPoints(size), circlePoints(size)]
        let from = shapes[legIndex]
        let to = shapes[(legIndex + 1) % 3]

        var path = Path()
        for i in 0..<samples {
            let pt = CGPoint(
                x: from[i].x + (to[i].x - from[i].x) * CGFloat(m),
                y: from[i].y + (to[i].y - from[i].y) * CGFloat(m)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        ctx.stroke(
            path, with: .color(.brandMint),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    private static func linePoints(_ size: CGSize) -> [CGPoint] {
        (0..<samples).map { i in
            let a = CGFloat(i) / CGFloat(samples - 1)
            return CGPoint(x: 30 + (size.width - 60) * a, y: size.height / 2)
        }
    }

    private static func hookPoints(_ size: CGSize) -> [CGPoint] {
        let rect = CGRect(x: 45, y: 20, width: size.width - 90, height: size.height - 40)
        return (0..<samples).map { i in
            HookCurve.point(at: Double(i) / Double(samples - 1), in: rect)
        }
    }

    private static func circlePoints(_ size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let r: CGFloat = 58
        // Starts at the bottom and runs counterclockwise so the ends meet
        // where the hook's ends sit — keeps the morph from crossing itself.
        return (0..<samples).map { i in
            let a = Double(i) / Double(samples - 1)
            let angle = .pi / 2 + a * 2 * .pi
            return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
        }
    }
}

/// A dot that breathes. The quietest possible signal that work is happening.
private enum PulseVariant {
    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let period = 2.0
        let phase = t.truncatingRemainder(dividingBy: period) / period
        let breathe = 0.5 - 0.5 * cos(2 * .pi * phase)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let glowR = 14 + 12 * CGFloat(breathe)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2
            )),
            with: .color(.brandMint.opacity(0.10 + 0.12 * breathe))
        )
        let r = 6 + 2.5 * CGFloat(breathe)
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .color(.brandMint)
        )
    }
}

/// A comet passing back and forth along a fixed baseline — the underline
/// from the launch wordmark, kept alive while the app works.
private enum SweepVariant {
    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let period = 2.2
        let phase = t.truncatingRemainder(dividingBy: period) / period
        let y = size.height / 2
        let minX: CGFloat = 30
        let maxX = size.width - 30

        var base = Path()
        base.move(to: CGPoint(x: minX, y: y))
        base.addLine(to: CGPoint(x: maxX, y: y))
        ctx.stroke(base, with: .color(.white.opacity(0.12)), lineWidth: 2)

        // Ping-pong with ease at both ends; the trail streams behind the
        // direction of travel.
        let pp = phase < 0.5 ? phase * 2 : 2 - phase * 2
        let eased = pp * pp * (3 - 2 * pp)
        let headX = minX + (maxX - minX) * CGFloat(eased)
        let dir: CGFloat = phase < 0.5 ? 1 : -1
        let steps = 24
        for i in 1...steps {
            let a = Double(i) / Double(steps)
            let x0 = headX - dir * 46 * CGFloat(1 - a)
            let x1 = headX - dir * 46 * CGFloat(1 - a + 1.0 / Double(steps))
            guard x0 >= minX, x0 <= maxX else { continue }
            var seg = Path()
            seg.move(to: CGPoint(x: x0, y: y))
            seg.addLine(to: CGPoint(x: min(max(x1, minX), maxX), y: y))
            ctx.stroke(
                seg, with: .color(.brandMint.opacity(0.05 + 0.7 * a)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
        ctx.fill(
            Path(ellipseIn: CGRect(x: headX - 4.5, y: y - 4.5, width: 9, height: 9)),
            with: .color(.brandMint)
        )
    }
}

#Preview {
    AnimationLabView()
}

#Preview("Composed") {
    ZStack {
        Color.black.ignoresSafeArea()
        ComposedWaitPage()
    }
    .preferredColorScheme(.dark)
}

#Preview("Morph frames") {
    // The shape morph unrolled: line → hook → circle → line.
    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
        ForEach([[0.55, 0.9, 1.35], [1.95, 2.3, 2.75], [3.35, 3.7, 4.15]], id: \.self) { row in
            GridRow {
                ForEach(row, id: \.self) { t in
                    Canvas { ctx, size in
                        ShapeMorphVariant.draw(ctx, size, t)
                    }
                    .frame(width: 110, height: 120)
                    .border(.white.opacity(0.15))
                    .overlay(alignment: .topLeading) {
                        Text("\(t, specifier: "%.2f")s")
                            .font(.caption2).foregroundStyle(.secondary).padding(2)
                    }
                }
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
#endif
