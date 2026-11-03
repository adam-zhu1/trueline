import CoreGraphics
import ImageIO
import Testing
@testable import Trueline

/// BallDetector.focusRegion: the native-resolution crop the detector reruns on
/// when the full frame loses a small far-lane ball. Vision wants it in the
/// display-oriented image, normalized, origin bottom-left.
@Suite("Far-lane focus crop")
struct FocusRegionTests {
    // A portrait iPhone clip: 1920x1080 raw buffer, displayed rotated (.right).
    static let rawW = 1920.0
    static let rawH = 1080.0

    @Test("crop is a focusSidePx square in display pixels")
    func squareInPixels() {
        let r = BallDetector.focusRegion(
            around: CGPoint(x: 960, y: 540), rawW: Self.rawW, rawH: Self.rawH, orientation: .right
        )
        // Displayed frame is 1080 wide x 1920 tall.
        #expect(abs(r.width * 1080 - BallDetector.focusSidePx) < 1e-9)
        #expect(abs(r.height * 1920 - BallDetector.focusSidePx) < 1e-9)
    }

    @Test("crop is centered on the predicted ball when it fits")
    func centered() {
        // Raw (700, 400) under .right displays at u = 1 - 400/1080, v = 700/1920.
        let r = BallDetector.focusRegion(
            around: CGPoint(x: 700, y: 400), rawW: Self.rawW, rawH: Self.rawH, orientation: .right
        )
        let u = 1 - 400.0 / 1080
        let vBottomUp = 1 - 700.0 / 1920
        #expect(abs(Double(r.midX) - u) < 1e-9)
        #expect(abs(Double(r.midY) - vBottomUp) < 1e-9)
    }

    @Test("crop slides inside the frame near an edge instead of leaving it",
          arguments: [CGPoint(x: 0, y: 0), CGPoint(x: 1920, y: 1080), CGPoint(x: 5, y: 1075)])
    func staysInBounds(point: CGPoint) {
        let r = BallDetector.focusRegion(
            around: point, rawW: Self.rawW, rawH: Self.rawH, orientation: .right
        )
        #expect(r.minX >= 0 && r.minY >= 0)
        #expect(r.maxX <= 1 + 1e-12 && r.maxY <= 1 + 1e-12)
    }
}
