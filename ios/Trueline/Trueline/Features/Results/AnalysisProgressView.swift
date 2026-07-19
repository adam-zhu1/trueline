import SwiftUI

/// Determinate, bowling-shaped progress for the analysis step: the pin rack
/// is the progress bar — ten ghost pins light up in mint one per 10%, head
/// pin first, row by row back. Driven by real analysis progress, never fake
/// motion; a percentage backs it up because a full clip can take a while on
/// device. When progress hits 1 the rack flashes and scatters — a strike —
/// which is why completion should linger briefly (see AnalysisView) before
/// the result appears. Under Reduce Motion the pins just stay lit.
struct AnalysisProgressView: View {
    /// Real progress, 0–1.
    var progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = false
    @State private var struck = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                ForEach(0..<PinRack.pins.count, id: \.self) { index in
                    let pin = PinRack.pins[index]
                    PinView(lit: litFraction(index), flash: flash)
                        .frame(width: pin.size.width, height: pin.size.height)
                        .position(pin.center)
                        .rotationEffect(
                            struck ? .degrees(pin.scatterSpin) : .zero,
                            anchor: .center
                        )
                        .offset(struck ? pin.scatterOffset : .zero)
                        .opacity(struck ? 0 : 1)
                }
            }
            .frame(width: PinRack.canvasSize.width, height: PinRack.canvasSize.height)
            .animation(.linear(duration: 0.3), value: progress)

            VStack(spacing: 6) {
                Text("Tracking the ball…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(progress > 0 ? "\(Int((progress * 100).rounded()))%" : " ")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: progress >= 1) { _, done in
            guard done, !reduceMotion else { return }
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.15)) { flash = true }
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeIn(duration: 0.45)) { struck = true }
            }
        }
    }

    /// Pin `index` fills across its own tenth of the progress range, so the
    /// rack lights continuously instead of popping a pin at a time.
    private func litFraction(_ index: Int) -> Double {
        min(max(progress * 10 - Double(index), 0), 1)
    }
}

/// One pin: a ghost outline with the mint version faded in on top.
private struct PinView: View {
    var lit: Double
    var flash: Bool

    var body: some View {
        ZStack {
            PinSilhouette()
                .fill(Color.white.opacity(0.05))
            PinSilhouette()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
            PinSilhouette()
                .fill(Color.brandMint)
                .opacity(lit)
                .shadow(color: Color.brandMint.opacity(flash ? 1 : 0.6 * lit),
                        radius: flash ? 10 : 6)
        }
    }
}

/// Rack layout seen from the approach — head pin nearest (largest, lowest),
/// back row deepest. Lateral spacing is true to the rack (6 in offsets);
/// depth is exaggerated and back rows shrink slightly, matching the
/// perspective language of OnboardingArtView. Lighting order is pins 1–10.
private enum PinRack {
    static let canvasSize = CGSize(width: 220, height: 190)

    struct Pin {
        let center: CGPoint
        let size: CGSize
        let scatterOffset: CGSize
        let scatterSpin: Double
    }

    static let pins: [Pin] = {
        // (row, lateral position in 6 in units): pins 1, 2–3, 4–6, 7–10.
        let layout: [(row: Int, offsets: [Double])] = [
            (0, [0]), (1, [-1, 1]), (2, [-2, 0, 2]), (3, [-3, -1, 1, 3]),
        ]
        let unitAcross = 24.0        // 6 in of rack width, in points
        let rowRise = 38.0           // exaggerated row depth
        let frontPinHeight = 40.0
        return layout.flatMap { row in
            row.offsets.map { off in
                let scale = pow(0.90, Double(row.row))
                let height = frontPinHeight * scale
                let center = CGPoint(
                    x: canvasSize.width / 2 + off * unitAcross * (1 - 0.04 * Double(row.row)),
                    y: canvasSize.height - 24 - Double(row.row) * rowRise
                )
                // A strike throws pins up-lane and outward: away from a point
                // just in front of the head pin, harder for the front rows.
                let origin = CGPoint(x: canvasSize.width / 2, y: canvasSize.height + 30)
                let dx = center.x - origin.x, dy = center.y - origin.y
                let len = max((dx * dx + dy * dy).squareRoot(), 1)
                let force = 110.0 * (1 - 0.12 * Double(row.row))
                return Pin(
                    center: center,
                    size: CGSize(width: height * 0.42, height: height),
                    scatterOffset: CGSize(width: dx / len * force, height: dy / len * force),
                    scatterSpin: off == 0 ? 24 : off * 30
                )
            }
        }
    }()
}

/// Hand-drawn pin outline: a half-width profile (head bump, neck pinch,
/// belly, tapered base) sampled down one side and mirrored up the other.
private struct PinSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let steps = 36
        // t runs top (0) to bottom (1); result is a fraction of rect half-width.
        func halfWidth(_ t: Double) -> Double {
            let head = 0.52 * exp(-pow((t - 0.14) / 0.115, 2))
            let belly = 0.90 * exp(-pow((t - 0.64) / 0.235, 2))
            // Quarter-circle cap so the head closes round instead of pointed.
            let cap = t < 0.07 ? (1 - pow(1 - t / 0.07, 2)).squareRoot() : 1
            return (0.10 + head + belly) * cap
        }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let dx = halfWidth(t) * rect.width / 2
            let y = rect.minY + t * rect.height
            left.append(CGPoint(x: rect.midX - dx, y: y))
            right.append(CGPoint(x: rect.midX + dx, y: y))
        }
        var path = Path()
        path.move(to: left[0])
        for pt in left.dropFirst() { path.addLine(to: pt) }
        for pt in right.reversed() { path.addLine(to: pt) }
        path.closeSubpath()
        return path
    }
}

#Preview("Mid-analysis") {
    ZStack {
        Color.black.ignoresSafeArea()
        AnalysisProgressView(progress: 0.62)
    }
}

#Preview("Nearly done") {
    ZStack {
        Color.black.ignoresSafeArea()
        AnalysisProgressView(progress: 0.97)
    }
}
