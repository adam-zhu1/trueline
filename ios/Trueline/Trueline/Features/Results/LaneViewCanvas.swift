import SwiftUI

/// Top-down lane diagram — port of draw_lane_view in src/ball_tracking.py
/// (Specto-style): board grid, foul/dot/pin reference lines, arrow V, pin deck
/// with pocket highlight, and the smoothed ball path with arrow-crossing and
/// breakpoint markers. SwiftUI Canvas renders vector-sharp, replacing the
/// prototype's 2× raster scaling.
struct LaneViewCanvas: View {
    var result: ShotResult

    // Palette (from src/ui.py, BGR→RGB).
    private let accent = Color(red: 1.0, green: 140 / 255, blue: 0)
    private let accentDim = Color(red: 200 / 255, green: 100 / 255, blue: 0)
    private let laneFill = Color(red: 55 / 255, green: 55 / 255, blue: 60 / 255)
    private let laneBorder = Color(red: 70 / 255, green: 75 / 255, blue: 80 / 255)
    private let gridColor = Color(red: 65 / 255, green: 70 / 255, blue: 75 / 255)
    private let gutterColor = Color(red: 38 / 255, green: 38 / 255, blue: 40 / 255)
    private let refLine = Color(red: 180 / 255, green: 100 / 255, blue: 0)
    private let deckFill = Color(red: 35 / 255, green: 35 / 255, blue: 38 / 255)

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 22
            let laneRect = CGRect(
                x: inset, y: inset + 44,
                width: size.width - inset * 2,
                height: size.height - inset * 2 - 44 - 18
            )

            func boardX(_ board: Double) -> CGFloat {
                let t = (board - 1) / 38.0
                return laneRect.minX + laneRect.width * (1.0 - t)
            }
            func feetY(_ feet: Double) -> CGFloat {
                laneRect.minY + laneRect.height * (1.0 - feet / 60.0)
            }

            // Gutters + lane surface
            let gw: CGFloat = 6
            context.fill(
                Path(CGRect(x: laneRect.minX - gw, y: laneRect.minY, width: gw, height: laneRect.height)),
                with: .color(gutterColor)
            )
            context.fill(
                Path(CGRect(x: laneRect.maxX, y: laneRect.minY, width: gw, height: laneRect.height)),
                with: .color(gutterColor)
            )
            context.fill(Path(laneRect), with: .color(laneFill))
            context.stroke(Path(laneRect), with: .color(laneBorder), lineWidth: 1)

            // Board grid every 5 boards
            for b in stride(from: 5, through: 35, by: 5) {
                let x = boardX(Double(b))
                var line = Path()
                line.move(to: CGPoint(x: x, y: laneRect.minY))
                line.addLine(to: CGPoint(x: x, y: laneRect.maxY))
                context.stroke(line, with: .color(gridColor), lineWidth: 1)
                context.draw(
                    Text("\(b)").font(.system(size: 9)).foregroundStyle(.secondary),
                    at: CGPoint(x: x, y: laneRect.maxY + 9)
                )
            }

            // Foul line (0 ft) and dashed dot line (6 ft)
            for (feet, dash, width) in [(0.0, [CGFloat](), 2.0), (6.0, [CGFloat(8), CGFloat(6)], 1.0)] {
                let y = feetY(feet)
                var line = Path()
                line.move(to: CGPoint(x: laneRect.minX, y: y))
                line.addLine(to: CGPoint(x: laneRect.maxX, y: y))
                context.stroke(
                    line, with: .color(refLine),
                    style: StrokeStyle(lineWidth: width, dash: dash)
                )
            }

            // Arrow V
            let arrowBoards: [Double] = [5, 10, 15, 20, 25, 30, 35]
            var vPath = Path()
            for (i, b) in arrowBoards.enumerated() {
                let pt = CGPoint(x: boardX(b), y: feetY(arrowFeet(atBoard: b)))
                if i == 0 { vPath.move(to: pt) } else { vPath.addLine(to: pt) }
            }
            context.stroke(vPath, with: .color(accentDim), lineWidth: 1)
            for b in arrowBoards {
                let pt = CGPoint(x: boardX(b), y: feetY(arrowFeet(atBoard: b)))
                var tri = Path()
                tri.move(to: CGPoint(x: pt.x, y: pt.y - 4))
                tri.addLine(to: CGPoint(x: pt.x - 3.5, y: pt.y + 3))
                tri.addLine(to: CGPoint(x: pt.x + 3.5, y: pt.y + 3))
                tri.closeSubpath()
                context.fill(tri, with: .color(accent))
            }

            // Pin deck: head pin centered at 60 ft, pins 12 in apart, lateral
            // positions exact in boards (pocket alignment true); row depth is
            // schematic because the diagram compresses length ~6× vs width.
            let boardsPer6In = (6.0 / LaneGeometry.laneWidthInches) * 39.0
            let headBoard = 20.0
            let pinLineY = feetY(60)
            let rowDY: CGFloat = 16
            let pinR: CGFloat = 5
            let pinRows: [[Double]] = [[0], [-1, 1], [-2, 0, 2], [-3, -1, 1, 3]]
            let deckTop = pinLineY - CGFloat(pinRows.count - 1) * rowDY - pinR - 4
            context.fill(
                Path(CGRect(x: laneRect.minX, y: deckTop, width: laneRect.width, height: pinLineY - deckTop)),
                with: .color(deckFill)
            )
            var pinLine = Path()
            pinLine.move(to: CGPoint(x: laneRect.minX, y: pinLineY))
            pinLine.addLine(to: CGPoint(x: laneRect.maxX, y: pinLineY))
            context.stroke(pinLine, with: .color(refLine), lineWidth: 2)

            // Pocket guide: dashed line down-lane from the pocket gap (~board 17.2)
            let pocketX = boardX(headBoard - boardsPer6In / 2.0)
            var pocket = Path()
            pocket.move(to: CGPoint(x: pocketX, y: pinLineY))
            pocket.addLine(to: CGPoint(x: pocketX, y: feetY(48)))
            context.stroke(
                pocket, with: .color(accentDim),
                style: StrokeStyle(lineWidth: 1, dash: [5, 7])
            )

            for (ri, offsets) in pinRows.enumerated() {
                let py = pinLineY - CGFloat(ri) * rowDY
                for off in offsets {
                    let b = headBoard + off * boardsPer6In
                    let px = boardX(b)
                    // Pocket pins: head pin + the pocket-side row-2 pin.
                    let isPocket = ri == 0 || (ri == 1 && off < 0)
                    let rect = CGRect(x: px - pinR, y: py - pinR, width: pinR * 2, height: pinR * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(isPocket ? accent : Color(white: 0.86)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Color(white: 0.16)), lineWidth: 1)
                }
            }

            // Ball path (already smoothed + trimmed by the analyzer)
            if result.path.count >= 2 {
                var path = Path()
                for (i, sample) in result.path.enumerated() {
                    let pt = CGPoint(x: boardX(sample.board), y: feetY(sample.feet))
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                context.stroke(
                    path, with: .color(accent),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            }

            // Markers: arrow crossing (triangle) and breakpoint (circle)
            if let ab = result.arrowBoard {
                marker(
                    &context, at: CGPoint(x: boardX(ab), y: feetY(arrowFeet(atBoard: ab))),
                    label: String(format: "%.1f", ab), triangle: true
                )
            }
            if let bb = result.breakpointBoard, let bf = result.breakpointFeet {
                marker(
                    &context, at: CGPoint(x: boardX(bb), y: feetY(bf)),
                    label: String(format: "%.1f", bb), triangle: false
                )
            }
        }
        .background(Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .aspectRatio(0.62, contentMode: .fit)
    }

    private func marker(_ context: inout GraphicsContext, at pt: CGPoint, label: String, triangle: Bool) {
        if triangle {
            var tri = Path()
            tri.move(to: CGPoint(x: pt.x, y: pt.y - 5))
            tri.addLine(to: CGPoint(x: pt.x - 5, y: pt.y + 4))
            tri.addLine(to: CGPoint(x: pt.x + 5, y: pt.y + 4))
            tri.closeSubpath()
            context.fill(tri, with: .color(accent))
        } else {
            let r: CGFloat = 5
            context.fill(
                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                with: .color(accent)
            )
        }
        let text = Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: 60, height: 20))
        let pill = CGRect(
            x: pt.x + 9, y: pt.y - size.height / 2 - 3,
            width: size.width + 12, height: size.height + 6
        )
        context.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(.black.opacity(0.6)))
        context.draw(resolved, at: CGPoint(x: pill.midX, y: pill.midY))
    }
}

#Preview {
    LaneViewCanvas(result: ShotResult(
        speedMph: 17.2,
        arrowBoard: 14.5,
        breakpointBoard: 6.8,
        breakpointFeet: 42,
        entryAngleDegrees: 4.1,
        path: stride(from: 0.0, through: 58.0, by: 1.0).map { ft in
            let t = ft / 58.0
            return (board: 18 - 11 * t + 8 * t * t, feet: ft)
        },
        trackedFrames: 120
    ))
    .padding()
}
