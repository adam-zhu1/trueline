import SwiftUI

/// Instrument-style lane view (design locked with Adam in the Trueline
/// Claude Design project, July 2026). Geometry is honest: points-per-foot
/// with true 60 ft length and 3.5× width exaggeration — his pick from a
/// rendered width ladder; true 1:17 read too skinny. Lateral-adjacent depth
/// (pin rows, deck) scales at 75% of that so the rack keeps a near-true
/// triangle with a slight deliberate squish. Rendering is quiet: gradient
/// surface with no border box, one hairline seam per arrow board, dim mint
/// arrows, small soft pins with a glowing pocket pair — and the path as the
/// unmistakable hero, mint core over a soft glow. Numbers live in the side
/// margins with leader lines, never inside the strip.
struct LaneViewCanvas: View {
    var result: ShotResult
    /// Compact mode fills whatever frame the caller gives (the side panel
    /// next to the recording) and drops margin labels.
    var compact = false
    /// Earlier paths from the same session, oldest first, drawn dim beneath
    /// the primary path so a mid-session line change reads at a glance.
    var overlayPaths: [[(board: Double, feet: Double)]] = []

    /// Width exaggeration over true scale, and the softer factor used for
    /// depth cheats (pin rows, deck) so the rack shape holds.
    private let ex: Double = 3.5
    private let depthEx: Double = 3.5 * 0.75

    private let mint = Color.brandMint
    private let mintDim = Color.brandMintDim
    private let cardBase = Color(red: 13 / 255, green: 14 / 255, blue: 15 / 255)
    private let surfaceNear = Color(red: 28 / 255, green: 29 / 255, blue: 31 / 255)
    private let surfaceFar = Color(red: 20 / 255, green: 21 / 255, blue: 22 / 255)

    var body: some View {
        if compact {
            laneCanvas
        } else {
            // Tall card: the lane's long silhouette plus label margins.
            laneCanvas.aspectRatio(0.5, contentMode: .fit)
        }
    }

    private var laneCanvas: some View {
        Canvas { context, size in
            let topPad: CGFloat = compact ? 14 : 26
            let botPad: CGFloat = compact ? 14 : 26
            let drawnFeet = 60.0 + 3.0 * depthEx
            let ppf = (size.height - topPad - botPad) / drawnFeet
            let laneW = min(ppf * (41.5 / 12) * ex, size.width * 0.64)
            let gw = laneW * 0.18
            let laneX = (size.width - laneW) / 2
            let laneY = topPad + ppf * 3 * depthEx
            let laneH = ppf * 60
            let laneRect = CGRect(x: laneX, y: laneY, width: laneW, height: laneH)

            func boardX(_ board: Double) -> CGFloat {
                laneX + laneW * (1.0 - (board - 1) / 38.0)
            }
            func feetY(_ feet: Double) -> CGFloat {
                laneY + laneH * (1.0 - feet / 60.0)
            }

            // Gutters: dark recessed channels
            context.fill(
                Path(CGRect(x: laneX - gw, y: laneY, width: gw, height: laneH)),
                with: .color(.black.opacity(0.5))
            )
            context.fill(
                Path(CGRect(x: laneX + laneW, y: laneY, width: gw, height: laneH)),
                with: .color(.black.opacity(0.5))
            )

            // Surface: barely-there vertical gradient, no border box
            context.fill(
                Path(laneRect),
                with: .linearGradient(
                    Gradient(colors: [surfaceNear, surfaceFar]),
                    startPoint: CGPoint(x: laneRect.midX, y: laneRect.maxY),
                    endPoint: CGPoint(x: laneRect.midX, y: laneRect.minY)
                )
            )

            // One hairline seam per arrow board
            for b in stride(from: 5.0, through: 35.0, by: 5.0) {
                var seam = Path()
                seam.move(to: CGPoint(x: boardX(b), y: laneRect.minY))
                seam.addLine(to: CGPoint(x: boardX(b), y: laneRect.maxY))
                context.stroke(seam, with: .color(.white.opacity(0.05)), lineWidth: 1)
            }

            // Foul line, across lane and gutters
            var foul = Path()
            foul.move(to: CGPoint(x: laneX - gw, y: feetY(0)))
            foul.addLine(to: CGPoint(x: laneX + laneW + gw, y: feetY(0)))
            context.stroke(foul, with: .color(mintDim), lineWidth: compact ? 1.5 : 2)

            // Arrows: the V at ~15 ft, quiet dim-mint triangles
            let arrowSize = min(6.5, max(2.2, laneW * 0.06))
            for b in stride(from: 5.0, through: 35.0, by: 5.0) {
                let depth = 15 + 1.5 * (1 - abs(b - 20) / 15)
                let pt = CGPoint(x: boardX(b), y: feetY(depth))
                var tri = Path()
                tri.move(to: CGPoint(x: pt.x, y: pt.y - arrowSize))
                tri.addLine(to: CGPoint(x: pt.x - arrowSize * 0.72, y: pt.y + arrowSize * 0.6))
                tri.addLine(to: CGPoint(x: pt.x + arrowSize * 0.72, y: pt.y + arrowSize * 0.6))
                tri.closeSubpath()
                context.fill(tri, with: .color(mintDim.opacity(0.85)))
            }

            // Pin rack: rows 10.4 in deep (depth-exaggerated), pins 12 in
            // apart at true boards, small and quiet; pocket pair glows.
            let rowDY = ppf * (10.4 / 12) * depthEx
            let pinR = max(1.4, min(ppf * (4.75 / 24) * ex, rowDY * 0.42) * 0.7)
            let deckTop = feetY(60) - 3 * rowDY - pinR - 4
            context.fill(
                Path(CGRect(
                    x: laneX - gw, y: deckTop,
                    width: laneW + gw * 2, height: feetY(60) - deckTop + pinR + 4
                )),
                with: .color(.black.opacity(0.35))
            )
            let boardsPer6In = (6.0 / LaneGeometry.laneWidthInches) * 39.0
            let pinRows: [[Double]] = [[0], [-1, 1], [-2, 0, 2], [-3, -1, 1, 3]]
            for (ri, offsets) in pinRows.enumerated() {
                let py = feetY(60) - CGFloat(ri) * rowDY
                for off in offsets {
                    let isPocket = ri == 0 || (ri == 1 && off < 0)
                    let px = boardX(20.0 + off * boardsPer6In)
                    if isPocket {
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: px - pinR * 2.8, y: py - pinR * 2.8,
                                width: pinR * 5.6, height: pinR * 5.6
                            )),
                            with: .radialGradient(
                                Gradient(colors: [mint.opacity(0.28), mint.opacity(0)]),
                                center: CGPoint(x: px, y: py),
                                startRadius: 0, endRadius: pinR * 2.8
                            )
                        )
                    }
                    context.fill(
                        Path(ellipseIn: CGRect(x: px - pinR, y: py - pinR, width: pinR * 2, height: pinR * 2)),
                        with: .color(isPocket ? mint.opacity(0.92) : .white.opacity(0.55))
                    )
                }
            }

            // Earlier session paths, dimmer the older they are
            for (i, overlay) in overlayPaths.enumerated() where overlay.count >= 2 {
                var path = Path()
                for (j, sample) in overlay.enumerated() {
                    let pt = CGPoint(x: boardX(sample.board), y: feetY(min(sample.feet, 60)))
                    if j == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                let recency = overlayPaths.count > 1
                    ? Double(i) / Double(overlayPaths.count - 1)
                    : 1.0
                context.stroke(
                    path, with: .color(mint.opacity(0.14 + 0.20 * recency)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }

            // The path: soft glow pass, then the mint core
            if result.path.count >= 2 {
                var path = Path()
                for (i, sample) in result.path.enumerated() {
                    let pt = CGPoint(x: boardX(sample.board), y: feetY(min(sample.feet, 60)))
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                let glowW: CGFloat = compact ? 4.5 : min(6, laneW * 0.12)
                let coreW: CGFloat = compact ? 1.8 : 2.4
                context.stroke(
                    path, with: .color(mint.opacity(0.16)),
                    style: StrokeStyle(lineWidth: glowW, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    path, with: .color(mint),
                    style: StrokeStyle(lineWidth: coreW, lineCap: .round, lineJoin: .round)
                )
            }

            // Breakpoint: marker on the path, number out in the right margin
            if let bb = result.breakpointBoard, let bf = result.breakpointFeet {
                let pt = CGPoint(x: boardX(bb), y: feetY(min(bf, 60)))
                let r: CGFloat = compact ? 2.6 : 3.4
                context.fill(
                    Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                    with: .color(mint)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                    with: .color(.white), lineWidth: 1.2
                )
                if !compact {
                    marginLabel(
                        &context,
                        value: String(format: "%.1f", bb), caption: "BREAK",
                        from: CGPoint(x: pt.x + r + 2, y: pt.y),
                        to: laneX + laneW + gw + 10, trailing: false
                    )
                }
            }

            // Entry angle at the pocket, labeled in the left margin
            if !compact, let ea = result.entryAngleDegrees, let eb = result.entryBoard {
                let pt = CGPoint(x: boardX(eb), y: feetY(58))
                marginLabel(
                    &context,
                    value: String(format: "%.1f°", ea), caption: "ENTRY",
                    from: CGPoint(x: pt.x - 4, y: pt.y),
                    to: laneX - gw - 10, trailing: true
                )
            }
        }
        .background(cardBase)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// A margin number with a thin leader line back to its point on the lane.
    private func marginLabel(
        _ context: inout GraphicsContext,
        value: String, caption: String,
        from: CGPoint, to labelX: CGFloat, trailing: Bool
    ) {
        var leader = Path()
        leader.move(to: from)
        leader.addLine(to: CGPoint(x: labelX + (trailing ? 4 : -4), y: from.y))
        context.stroke(leader, with: .color(.white.opacity(0.25)), lineWidth: 1)

        let anchor: UnitPoint = trailing ? .trailing : .leading
        context.draw(
            context.resolve(
                Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            ),
            at: CGPoint(x: labelX, y: from.y - 1), anchor: anchor
        )
        context.draw(
            context.resolve(
                Text(caption).font(.system(size: 8, weight: .medium)).kerning(0.6)
                    .foregroundStyle(.white.opacity(0.4))
            ),
            at: CGPoint(x: labelX, y: from.y + 12), anchor: anchor
        )
    }
}

#Preview("Standalone") {
    LaneViewCanvas(result: .textbookSample)
        .padding()
        .background(Color.black)
}

#Preview("Compact") {
    HStack {
        Color(white: 0.1).frame(width: 220, height: 380)
        LaneViewCanvas(result: .textbookSample, compact: true)
            .frame(width: 104, height: 380)
    }
    .padding()
    .background(Color.black)
}

extension ShotResult {
    /// Textbook right-hand shot for previews: laydown 18.5, breakpoint board
    /// 6 at 42 ft, entry at board 17.3 into the 1–3 gap at ~6°.
    static var textbookSample: ShotResult {
        ShotResult(
            speedMph: 17.2,
            arrowBoard: 13.4,
            breakpointBoard: 6.0,
            breakpointFeet: 42,
            entryAngleDegrees: 6.2,
            entryBoard: 17.3,
            path: stride(from: 0.0, through: 59.6, by: 0.75).map { ft in
                let board: Double
                if ft <= 42 {
                    let s = sin(ft / 42 * .pi / 2)
                    board = 18.5 - 12.5 * pow(s, 1.4)
                } else {
                    let t = (ft - 42) / 18
                    board = 6 + 11.3 * t * t
                }
                return (board: board, feet: ft)
            },
            videoPath: [],
            videoDisplaySize: CGSize(width: 1080, height: 1920),
            trackedFrames: 120
        )
    }
}
