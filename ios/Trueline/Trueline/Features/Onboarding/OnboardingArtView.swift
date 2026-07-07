import SwiftUI

/// Hand-drawn onboarding diagrams — a behind-the-approach lane in light
/// perspective, dressed per page. Replaces the giant SF Symbols so the intro
/// shows the actual setup instead of clip art. Same neutral/mint language as
/// LaneViewCanvas (values from src/ui.py).
struct OnboardingArtView: View {
    enum Art {
        /// Phone propped behind the approach, view cone covering the lane.
        case setup
        /// Four corner handles on the lane, ready to drag.
        case calibrate
        /// A tracked hook with metric callouts.
        case metrics
        /// Ball arriving at the 1–3 pocket (hand page).
        case pocket
    }

    let art: Art

    private let laneFill = Color(red: 55 / 255, green: 55 / 255, blue: 60 / 255)
    private let laneBorder = Color(red: 70 / 255, green: 75 / 255, blue: 80 / 255)
    private let gridColor = Color(red: 65 / 255, green: 70 / 255, blue: 75 / 255)

    var body: some View {
        Canvas { context, size in
            switch art {
            case .pocket:
                drawPocket(context, size: size)
            default:
                drawLane(context, size: size)
            }
        }
        .frame(width: 230, height: art == .pocket ? 120 : 200)
    }

    // MARK: Perspective lane (setup / calibrate / metrics)

    /// Lane corners in a 230×200 canvas: wide at the foul line (bottom),
    /// converging toward the pins.
    private var bottomY: CGFloat { 158 }
    private var topY: CGFloat { 34 }
    private func leftX(_ t: CGFloat) -> CGFloat { 62 + (97 - 62) * t }
    private func rightX(_ t: CGFloat) -> CGFloat { 168 + (133 - 168) * t }
    private func depthY(_ t: CGFloat) -> CGFloat { bottomY + (topY - bottomY) * t }
    private func point(depth t: CGFloat, across f: CGFloat) -> CGPoint {
        CGPoint(x: leftX(t) + (rightX(t) - leftX(t)) * f, y: depthY(t))
    }

    private func drawLane(_ context: GraphicsContext, size: CGSize) {
        // Surface
        var lane = Path()
        lane.move(to: point(depth: 0, across: 0))
        lane.addLine(to: point(depth: 0, across: 1))
        lane.addLine(to: point(depth: 1, across: 1))
        lane.addLine(to: point(depth: 1, across: 0))
        lane.closeSubpath()
        context.fill(lane, with: .color(laneFill))
        context.stroke(lane, with: .color(laneBorder), lineWidth: 1)

        // Board seams converging toward the pins
        for f in [0.25, 0.5, 0.75] {
            var seam = Path()
            seam.move(to: point(depth: 0, across: f))
            seam.addLine(to: point(depth: 1, across: f))
            context.stroke(seam, with: .color(gridColor), lineWidth: 1)
        }

        // Foul line
        var foul = Path()
        foul.move(to: point(depth: 0, across: 0))
        foul.addLine(to: point(depth: 0, across: 1))
        context.stroke(foul, with: .color(Color.brandMintDim), lineWidth: 2)

        // Arrows — the V, center arrow deepest
        for (i, f) in [0.17, 0.33, 0.5, 0.67, 0.83].enumerated() {
            let depth = 0.24 + 0.05 * (2 - abs(Double(i) - 2)) / 2
            let pt = point(depth: depth, across: f)
            var tri = Path()
            tri.move(to: CGPoint(x: pt.x, y: pt.y - 3.5))
            tri.addLine(to: CGPoint(x: pt.x - 2.5, y: pt.y + 2))
            tri.addLine(to: CGPoint(x: pt.x + 2.5, y: pt.y + 2))
            tri.closeSubpath()
            context.fill(tri, with: .color(Color.brandMintDim))
        }

        drawPins(context)

        switch art {
        case .setup: drawPhone(context)
        case .calibrate: drawHandles(context)
        case .metrics: drawTrackedPath(context)
        case .pocket: break
        }
    }

    /// Ten pins seen from the approach — head pin nearest, back row deepest.
    private func drawPins(_ context: GraphicsContext) {
        let rows: [(depth: CGFloat, count: Int)] = [
            (0.88, 1), (0.91, 2), (0.94, 3), (0.97, 4),
        ]
        for row in rows {
            for i in 0..<row.count {
                let spread = CGFloat(row.count - 1) * 0.11
                let f = 0.5 - spread / 2 + CGFloat(i) * (row.count > 1 ? spread / CGFloat(row.count - 1) : 0)
                let pt = point(depth: row.depth, across: f)
                context.fill(
                    Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)),
                    with: .color(Color(white: 0.86))
                )
            }
        }
    }

    private func drawPhone(_ context: GraphicsContext) {
        let phone = CGRect(x: 106, y: 168, width: 18, height: 30)
        // View cone first, so the phone sits on top of it
        for corner in [point(depth: 1, across: 0), point(depth: 1, across: 1)] {
            var ray = Path()
            ray.move(to: CGPoint(x: phone.midX, y: phone.minY))
            ray.addLine(to: corner)
            context.stroke(ray, with: .color(Color.brandMint.opacity(0.22)), lineWidth: 1)
        }
        context.fill(Path(roundedRect: phone, cornerRadius: 4), with: .color(Color(white: 0.1)))
        context.stroke(Path(roundedRect: phone, cornerRadius: 4), with: .color(Color.brandMint), lineWidth: 1.5)
        context.fill(
            Path(ellipseIn: CGRect(x: phone.midX - 1.5, y: phone.minY + 3, width: 3, height: 3)),
            with: .color(Color.brandMint)
        )
    }

    private func drawHandles(_ context: GraphicsContext) {
        let corners = [
            point(depth: 0, across: 0), point(depth: 0, across: 1),
            point(depth: 1, across: 1), point(depth: 1, across: 0),
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
                Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)),
                with: .color(Color.brandMint)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)),
                with: .color(.black.opacity(0.5)), lineWidth: 1
            )
        }
    }

    private func drawTrackedPath(_ context: GraphicsContext) {
        // The brand hook, projected onto the perspective lane. Board 39 is the
        // left edge from behind a right-hander.
        var path = Path()
        for step in 0...30 {
            let u = CGFloat(step) / 30
            let board = HookCurve.board(at: Double(u))
            let pt = point(depth: u * 0.9, across: (39 - board) / 38)
            if step == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.stroke(
            path, with: .color(Color.brandMint),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
        // Breakpoint marker
        let bp = point(
            depth: CGFloat(HookCurve.breakpoint) * 0.9,
            across: (39 - HookCurve.board(at: HookCurve.breakpoint)) / 38
        )
        context.fill(
            Path(ellipseIn: CGRect(x: bp.x - 3.5, y: bp.y - 3.5, width: 7, height: 7)),
            with: .color(Color.brandMint)
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: bp.x - 3.5, y: bp.y - 3.5, width: 7, height: 7)),
            with: .color(.white), lineWidth: 1
        )
        pill(context, text: "17.2 mph", at: CGPoint(x: 62, y: 118))
        pill(context, text: "4.6°", at: CGPoint(x: 168, y: 52))
    }

    private func pill(_ context: GraphicsContext, text: String, at center: CGPoint) {
        let resolved = context.resolve(
            Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white)
        )
        let size = resolved.measure(in: CGSize(width: 80, height: 20))
        let rect = CGRect(
            x: center.x - size.width / 2 - 6, y: center.y - size.height / 2 - 3,
            width: size.width + 12, height: size.height + 6
        )
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(.black.opacity(0.65)))
        context.stroke(
            Path(roundedRect: rect, cornerRadius: rect.height / 2),
            with: .color(Color.brandMintDim), lineWidth: 1
        )
        context.draw(resolved, at: center)
    }

    // MARK: Pocket motif (hand page)

    /// Top-down: pin triangle with the ball arriving at the 1–3 pocket.
    private func drawPocket(_ context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: 34)
        let dx: CGFloat = 17
        let dy: CGFloat = 15
        // Rows back-to-front so the head pin draws on top
        for row in (0...3).reversed() {
            for i in 0...row {
                let x = center.x + (CGFloat(i) - CGFloat(row) / 2) * dx
                let y = center.y - CGFloat(row) * dy + 2 * dy
                let pin = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
                let isPocket = row == 0 || (row == 1 && i == 1)
                context.fill(Path(ellipseIn: pin), with: .color(isPocket ? Color.brandMint : Color(white: 0.86)))
                context.stroke(Path(ellipseIn: pin), with: .color(Color(white: 0.16)), lineWidth: 1)
            }
        }
        // Ball curving in from the right toward the 1–3 gap, stopped short of
        // the deck so the ball doesn't merge into the pin cluster
        let ball = CGPoint(x: center.x + dx / 2 + 4, y: center.y + 2 * dy + 16)
        var path = Path()
        path.move(to: CGPoint(x: center.x + 58, y: 118))
        path.addQuadCurve(to: ball, control: CGPoint(x: center.x + 54, y: 78))
        context.stroke(
            path, with: .color(Color.brandMint),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: ball.x - 6, y: ball.y - 6, width: 12, height: 12)),
            with: .color(Color.brandMint)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        OnboardingArtView(art: .setup)
        OnboardingArtView(art: .calibrate)
        OnboardingArtView(art: .metrics)
        OnboardingArtView(art: .pocket)
    }
    .background(.black)
}
