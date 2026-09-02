import SwiftUI

/// Compact behind-the-approach lane sketch for the calibration header. It
/// answers "where on the lane is this landmark" before the user hunts for it
/// in the photo: placed taps are filled dots, the active target pulses, and
/// the refine stage shows the four drag handles around a mint rack. Same
/// hand-drawn language as OnboardingArtView, drawn long and narrow.
struct CalibrationGuideDiagram: View {
    enum Stage: Equatable {
        /// active = the target the user should tap now, nil once all placed.
        case tapping(active: Int?, placed: Int)
        case refining
    }

    let stage: Stage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let laneFill = Color(red: 55 / 255, green: 55 / 255, blue: 60 / 255)
    private let laneBorder = Color(red: 70 / 255, green: 75 / 255, blue: 80 / 255)

    static let size = CGSize(width: 84, height: 136)

    var body: some View {
        ZStack {
            Canvas { context, _ in
                drawLane(context)
                switch stage {
                case .tapping(_, let placed):
                    for index in 0..<min(placed, Self.targetSpots.count) {
                        dot(context, at: Self.point(Self.targetSpots[index]), color: Color.brandMint)
                    }
                case .refining:
                    drawCornerHandles(context)
                }
            }
            if case .tapping(let active?, _) = stage {
                PulsingRing(animated: !reduceMotion)
                    .position(Self.point(Self.targetSpots[active]))
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true) // decorative; the hint text carries the step
    }

    // MARK: Geometry

    /// Lane coords (depth 0 = foul line, 1 = pins; across 0 = left, 1 = right)
    /// for the six tap targets, in LandmarkFit.targets order.
    private static let targetSpots: [(depth: CGFloat, across: CGFloat)] = [
        (0, 1), (0, 0),          // foul line right, left
        (0.3, 0.1), (0.34, 0.5), (0.3, 0.9), // arrows: leftmost, middle, rightmost
        (0.86, 0.5),             // head pin
    ]

    private static func point(_ spot: (depth: CGFloat, across: CGFloat)) -> CGPoint {
        let bottomY: CGFloat = 128
        let topY: CGFloat = 10
        let left = 10 + (26 - 10) * spot.depth
        let right = 74 + (58 - 74) * spot.depth
        return CGPoint(
            x: left + (right - left) * spot.across,
            y: bottomY + (topY - bottomY) * spot.depth
        )
    }

    private func drawLane(_ context: GraphicsContext) {
        var lane = Path()
        lane.move(to: Self.point((0, 0)))
        lane.addLine(to: Self.point((0, 1)))
        lane.addLine(to: Self.point((1, 1)))
        lane.addLine(to: Self.point((1, 0)))
        lane.closeSubpath()
        context.fill(lane, with: .color(laneFill))
        context.stroke(lane, with: .color(laneBorder), lineWidth: 1)

        var foul = Path()
        foul.move(to: Self.point((0, 0)))
        foul.addLine(to: Self.point((0, 1)))
        context.stroke(foul, with: .color(Color.brandMintDim), lineWidth: 2)

        // The arrow V, center arrow deepest, dimmed so the highlight reads
        for (i, f) in [0.1, 0.23, 0.37, 0.5, 0.63, 0.77, 0.9].enumerated() {
            let depth = 0.3 + 0.04 * (3 - abs(Double(i) - 3)) / 3
            let pt = Self.point((depth, f))
            var tri = Path()
            tri.move(to: CGPoint(x: pt.x, y: pt.y - 2.5))
            tri.addLine(to: CGPoint(x: pt.x - 2, y: pt.y + 1.5))
            tri.addLine(to: CGPoint(x: pt.x + 2, y: pt.y + 1.5))
            tri.closeSubpath()
            context.fill(tri, with: .color(Color.brandMintDim.opacity(0.7)))
        }

        drawPins(context, mint: stage == .refining)
    }

    /// Ten pins, head pin nearest; lateral spread true to the rack.
    private func drawPins(_ context: GraphicsContext, mint: Bool) {
        let sixInches = 6.0 / LaneGeometry.laneWidthInches
        let rows: [(depth: CGFloat, offsets: [Double])] = [
            (0.86, [0]), (0.9, [-1, 1]), (0.94, [-2, 0, 2]), (0.98, [-3, -1, 1, 3]),
        ]
        for row in rows {
            for off in row.offsets {
                let pt = Self.point((row.depth, 0.5 + off * sixInches))
                context.fill(
                    Path(ellipseIn: CGRect(x: pt.x - 1.7, y: pt.y - 1.7, width: 3.4, height: 3.4)),
                    with: .color(mint ? Color.brandMint : Color(white: 0.86))
                )
            }
        }
    }

    /// Refine stage: the four corners the user drags, around the mint rack.
    private func drawCornerHandles(_ context: GraphicsContext) {
        let corners = [
            Self.point((0, 0)), Self.point((0, 1)),
            Self.point((1, 1)), Self.point((1, 0)),
        ]
        var quad = Path()
        quad.move(to: corners[0])
        for c in corners.dropFirst() { quad.addLine(to: c) }
        quad.closeSubpath()
        context.stroke(
            quad, with: .color(Color.brandMint.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )
        for c in corners {
            context.fill(
                Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)),
                with: .color(Color.brandMint)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)),
                with: .color(.black.opacity(0.5)), lineWidth: 1
            )
        }
    }

    private func dot(_ context: GraphicsContext, at pt: CGPoint, color: Color) {
        context.fill(
            Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
            with: .color(color)
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
            with: .color(.black.opacity(0.5)), lineWidth: 1
        )
    }
}

/// The active target marker: a solid dot with a ring that breathes outward.
/// Static ring when Reduce Motion is on.
private struct PulsingRing: View {
    let animated: Bool
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandMint)
                .frame(width: 7, height: 7)
            Circle()
                .stroke(Color.brandMint, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .scaleEffect(expanded ? 1.5 : 0.85)
                .opacity(expanded ? 0.1 : 0.9)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                expanded = true
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        CalibrationGuideDiagram(stage: .tapping(active: 0, placed: 0))
        CalibrationGuideDiagram(stage: .tapping(active: 3, placed: 3))
        CalibrationGuideDiagram(stage: .tapping(active: 5, placed: 5))
        CalibrationGuideDiagram(stage: .refining)
    }
    .padding()
    .background(.black)
}
