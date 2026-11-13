import CoreGraphics
import ImageIO
import Testing
@testable import Trueline

/// BallDetector.laneRegion: the main detection pass runs on the calibrated
/// lane's bounding box instead of the whole frame, so the 640 px letterbox
/// spends its pixels on the lane. Vision wants it display-oriented,
/// normalized, origin bottom-left.
@Suite("Lane-box detection region")
struct LaneRegionTests {
    static let size = CGSize(width: 1080, height: 1920)

    /// A lane that fills a narrow strip of the frame, like a phone set back
    /// or off to one side.
    static let narrow = LaneCorners(
        farLeft: CGPoint(x: 0.47, y: 0.30),
        farRight: CGPoint(x: 0.53, y: 0.30),
        nearRight: CGPoint(x: 0.66, y: 0.80),
        nearLeft: CGPoint(x: 0.34, y: 0.80)
    )

    @Test("region holds every lane corner and stays inside the frame")
    func containsLane() throws {
        let geometry = try #require(LaneGeometry(corners: Self.narrow, imageSize: Self.size, hand: .right))
        let r = try #require(BallDetector.laneRegion(
            geometry: geometry, rawW: Self.size.width, rawH: Self.size.height, orientation: .up))
        #expect(r.minX >= 0 && r.minY >= 0 && r.maxX <= 1 && r.maxY <= 1)
        for p in geometry.quad {
            // .up: oriented = raw; Vision's y runs bottom-up.
            let u = Double(p.x) / Self.size.width
            let vUp = 1 - Double(p.y) / Self.size.height
            #expect(Double(r.minX) <= u && u <= Double(r.maxX))
            #expect(Double(r.minY) <= vUp && vUp <= Double(r.maxY))
        }
        // and it is meaningfully smaller than the frame
        #expect(r.width * r.height < 0.5)
    }

    @Test("no region when the lane already fills most of the frame")
    func skipsFullFrameLane() throws {
        let wide = LaneCorners(
            farLeft: CGPoint(x: 0.30, y: 0.02),
            farRight: CGPoint(x: 0.70, y: 0.02),
            nearRight: CGPoint(x: 0.98, y: 0.97),
            nearLeft: CGPoint(x: 0.02, y: 0.97)
        )
        let geometry = try #require(LaneGeometry(corners: wide, imageSize: Self.size, hand: .right))
        #expect(BallDetector.laneRegion(
            geometry: geometry, rawW: Self.size.width, rawH: Self.size.height, orientation: .up) == nil)
    }
}
