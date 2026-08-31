import SwiftUI

/// The lane's known geometry (gutters, foul line, boards, arrows, pin rack)
/// reprojected through a corner calibration onto a video frame. Misalignment
/// between the drawing and the real lane is the whole feedback mechanism of
/// the calibrate refine step, and the same view doubles as the per-throw
/// drift check. The pin spots are the refine target: the far lane's markings
/// are trustworthy where its specular edges are not.
struct LaneOverlayView: View {
    let corners: LaneCorners
    let imageSize: CGSize
    /// Where the frame is drawn in the container (aspect-fit rect).
    let fittedRect: CGRect

    private static let arrowBoards: [Double] = [5, 10, 15, 20, 25, 30, 35]

    /// The aspect-fit rect a frame of `imageSize` occupies inside `container`,
    /// matching both the calibration screen's layout and AVKit's video gravity.
    static func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    var body: some View {
        Canvas { context, _ in
            guard let geometry = LaneGeometry(corners: corners, imageSize: imageSize, hand: .right) else { return }

            func view(_ tAcross: Double, _ feet: Double) -> CGPoint {
                let px = geometry.imagePoint(tAcross: tAcross, feet: feet)
                return CGPoint(
                    x: fittedRect.minX + px.x / imageSize.width * fittedRect.width,
                    y: fittedRect.minY + px.y / imageSize.height * fittedRect.height
                )
            }
            func line(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: CGFloat) {
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                context.stroke(path, with: .color(color), lineWidth: width)
            }

            // Board seams every fifth board, dim so the frame stays readable.
            for board in stride(from: 5.0, through: 35.0, by: 5.0) {
                let t = board / 39.0
                line(view(t, 0), view(t, 60), .white.opacity(0.22), 1)
            }
            // Lane outline: gutters, foul line, pin line.
            line(view(0, 0), view(0, 60), .accentColor, 2)
            line(view(1, 0), view(1, 60), .accentColor, 2)
            line(view(0, 0), view(1, 0), .accentColor, 2)
            line(view(0, 60), view(1, 60), .accentColor, 2)

            // Arrows: small triangles at the nominal V.
            for board in Self.arrowBoards {
                let feet = 15.0 - abs(board - 20.0) / 5.0 * 0.5
                let tip = view((board - 0.5) / 39.0, feet)
                var tri = Path()
                tri.move(to: CGPoint(x: tip.x, y: tip.y - 5))
                tri.addLine(to: CGPoint(x: tip.x - 4, y: tip.y + 4))
                tri.addLine(to: CGPoint(x: tip.x + 4, y: tip.y + 4))
                tri.closeSubpath()
                context.stroke(tri, with: .color(.accentColor), lineWidth: 1.5)
            }

            // Pin spots, sized to a real pin's width (about 4.5 boards).
            let deckLeft = view(1, 60)
            let deckRight = view(0, 60)
            let pxPerBoard = hypot(deckLeft.x - deckRight.x, deckLeft.y - deckRight.y) / 39
            let radius = max(2.23 * pxPerBoard, 3)
            for row in LandmarkFit.pinRows {
                for board in row.boards {
                    let center = view((board - 0.5) / 39.0, row.feet)
                    let circle = Path(ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    ))
                    context.stroke(circle, with: .color(.white), lineWidth: 1.5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
