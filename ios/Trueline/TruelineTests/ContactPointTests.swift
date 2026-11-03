import CoreGraphics
import ImageIO
import Testing
@testable import Trueline

/// ShotAnalyzer.contactRaw: the ball's contact point is the bottom of the
/// ball AS DISPLAYED, which is a different raw-buffer axis per orientation
/// (the Sep 7 Brooklyn bug added the radius to raw y on rotated clips).
@Suite("Orientation-aware contact point")
struct ContactPointTests {
    static let rawSize = CGSize(width: 1920, height: 1080)

    @Test("portrait iPhone clips decode as .right")
    func portraitTransformIsRight() {
        let portrait = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        #expect(ShotAnalyzer.orientation(from: portrait) == .right)
        #expect(ShotAnalyzer.orientation(from: .identity) == .up)
    }

    @Test(".right: display-down is raw +x, so the radius goes on x")
    func rightOrientation() {
        let contact = ShotAnalyzer.contactRaw(x: 700, y: 400, radius: 18, orientation: .right)
        #expect(contact == CGPoint(x: 718, y: 400))
    }

    @Test("contact point is directly below the center on screen",
          arguments: [CGImagePropertyOrientation.up, .down, .left, .right])
    func belowOnScreen(orientation: CGImagePropertyOrientation) {
        let w = Double(Self.rawSize.width), h = Double(Self.rawSize.height)
        let rotated = orientation == .left || orientation == .right
        let displayW = rotated ? h : w, displayH = rotated ? w : h

        func display(_ p: CGPoint) -> CGPoint {
            let (u, v) = BallDetector.rawToOriented(rx: Double(p.x) / w, ry: Double(p.y) / h, orientation: orientation)
            return CGPoint(x: u * displayW, y: v * displayH)
        }

        let center = CGPoint(x: 700, y: 400)
        let radius = 18.0
        let contact = ShotAnalyzer.contactRaw(x: 700, y: 400, radius: radius, orientation: orientation)
        let c = display(center), k = display(contact)
        #expect(isClose(Double(k.x), Double(c.x), 1e-9))
        #expect(isClose(Double(k.y - c.y), radius, 1e-9))
    }
}
