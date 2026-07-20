import SwiftUI

/// Branded cold-start moment, one idea only: the wordmark settles in, the
/// letters collapse left into a mint ball, and the ball rolls back across the
/// word's width drawing the brand line. Then the whole scene breathes out.
/// ~1.85 s on black, tap to skip, no artificial loading — the app behind it
/// is already ready. Reduce Motion gets a static wordmark instead.
struct LaunchAnimationView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var finished = false

    private static let word = Array("TrueLine")
    /// "Line" — the mint half of the wordmark — starts here.
    private static let mintFrom = 4

    // Timeline, seconds from start.
    private let wordIn = 0.3
    private let morphStart = 0.45
    private let morphStagger = 0.02
    private let morphDuration = 0.32
    private let rollStart = 0.95
    private let rollDuration = 0.5
    private let fadeStart = 1.6
    private let fadeDuration = 0.25
    private var totalDuration: Double { fadeStart + fadeDuration }

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

    fileprivate func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        var root = ctx
        root.opacity = 1 - clamp((t - fadeStart) / fadeDuration)

        let letters = Self.word.indices.map { i in
            root.resolve(
                Text(String(Self.word[i]))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(i >= Self.mintFrom ? Color.brandMint : Color.white)
            )
        }
        let sizes = letters.map { $0.measure(in: CGSize(width: 200, height: 120)) }
        let totalWidth = sizes.reduce(0) { $0 + $1.width }
        let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
        let startX = center.x - totalWidth / 2
        let lineY = center.y + (sizes.first?.height ?? 44) / 2 + 12
        // Where the letters gather and the roll begins.
        let gather = CGPoint(x: startX + 9, y: lineY - 9)

        // Wordmark: rises in as one piece, then each letter is drawn toward
        // the gather point, shrinking and fading — the word becomes the ball.
        let arrive = clamp(t / wordIn)
        let rise = (1 - arrive) * 10
        var penX = startX
        var gathered = 0.0
        for (i, letter) in letters.enumerated() {
            let home = CGPoint(x: penX + sizes[i].width / 2, y: center.y + rise)
            penX += sizes[i].width
            let m = clamp((t - morphStart - Double(i) * morphStagger) / morphDuration)
            // Motion leads, fade trails: the letter visibly travels to the
            // gather point and only disappears as it arrives, so the morph
            // reads as absorption rather than a fade-out.
            let eased = m * m * (3 - 2 * m)
            gathered += m / Double(letters.count)
            guard m < 1 else { continue }
            var layer = root
            layer.opacity = root.opacity * arrive * (1 - m * m)
            let pos = CGPoint(
                x: home.x + (gather.x - home.x) * eased,
                y: home.y + (gather.y - home.y) * eased
            )
            layer.translateBy(x: pos.x, y: pos.y)
            let scale = 1 - 0.7 * eased
            layer.scaleBy(x: scale, y: scale)
            layer.draw(letter, at: .zero)
        }

        // The ball forms from the gathered letters, then rolls the word's
        // width drawing the line.
        guard gathered > 0 else { return }
        let roll = clamp((t - rollStart) / rollDuration)
        let rollEased = roll * roll * (3 - 2 * roll)
        let ballX = gather.x + (startX + totalWidth - gather.x) * rollEased
        let ballR = 4 + 5 * clamp(gathered)

        if roll > 0 {
            var line = Path()
            line.move(to: CGPoint(x: gather.x, y: lineY))
            line.addLine(to: CGPoint(x: ballX, y: lineY))
            root.stroke(
                line, with: .color(.brandMint),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
        root.fill(
            Path(ellipseIn: CGRect(
                x: ballX - ballR * 2.1, y: gather.y - ballR * 2.1,
                width: ballR * 4.2, height: ballR * 4.2
            )),
            with: .color(.brandMint.opacity(0.18 * clamp(gathered)))
        )
        root.fill(
            Path(ellipseIn: CGRect(
                x: ballX - ballR, y: gather.y - ballR,
                width: ballR * 2, height: ballR * 2
            )),
            with: .color(.brandMint.opacity(clamp(gathered)))
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

/// The launch unrolled, for tuning: settle, morph, roll, fade.
private struct LaunchFrameGrid: View {
    private let view = LaunchAnimationView {}

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach([[0.2, 0.5, 0.65], [0.8, 0.95, 1.15], [1.35, 1.55, 1.75]], id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { t in
                        Canvas { ctx, size in
                            view.draw(ctx, size: size, t: t)
                        }
                        .frame(width: 240, height: 130)
                        .border(.white.opacity(0.15))
                        .overlay(alignment: .topLeading) {
                            Text("\(t, specifier: "%.2f")s")
                                .font(.caption2).foregroundStyle(.secondary).padding(2)
                        }
                    }
                }
            }
        }
        .scaleEffect(0.55)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview("Timeline frames") {
    LaunchFrameGrid()
}
