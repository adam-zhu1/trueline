import CoreGraphics
import Testing
@testable import Trueline

@Suite("LandmarkFit homography")
struct LandmarkFitTests {
    static let imageSize = CGSize(width: 1080, height: 1920)

    /// Ground truth: a down-lane perspective (lane coords → image pixels),
    /// built from a known corner quad so the expected corners are exact.
    static let quad: [CGPoint] = [
        CGPoint(x: 905, y: 1830),   // foul line, right gutter
        CGPoint(x: 160, y: 1790),   // foul line, left gutter
        CGPoint(x: 470, y: 260),    // pin deck, left gutter
        CGPoint(x: 640, y: 275),    // pin deck, right gutter
    ]
    static let laneCorners: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 60), CGPoint(x: 0, y: 60),
    ]

    static func truth() throws -> Homography {
        try #require(Homography(from: laneCorners, to: quad))
    }

    /// Scale-free comparison of two homographies.
    static func normalized(_ h: Homography) -> [Double] {
        h.m.map { $0 / h.m[8] }
    }

    @Test("least-squares DLT recovers a known homography from exact points")
    func leastSquaresRecovers() throws {
        let h = try Self.truth()
        var lane: [CGPoint] = LandmarkFit.targets.map(\.lane)
        lane += LaneModel.pins.map { CGPoint(x: LaneModel.tAcross(boardCenter: $0.board), y: $0.feet) }
        let image = lane.map(h.apply)
        let fitted = try #require(Homography(leastSquaresFrom: lane, to: image))
        for (a, b) in zip(Self.normalized(fitted), Self.normalized(h)) {
            #expect(isClose(a, b, 1e-6 * max(1, abs(b))))
        }
        // And the inverse maps image points back onto the lane.
        let back = try #require(fitted.inverted())
        for (l, p) in zip(lane, image) {
            #expect(isClose(back.apply(p), l, 1e-6))
        }
    }

    @Test("six synthetic taps fit back to the true lane corners")
    func cornersFromTaps() throws {
        let h = try Self.truth()
        let w = Double(Self.imageSize.width), hgt = Double(Self.imageSize.height)
        let taps = LandmarkFit.targets.map { target -> CGPoint in
            let p = h.apply(target.lane)
            return CGPoint(x: Double(p.x) / w, y: Double(p.y) / hgt)
        }
        let corners = try #require(LandmarkFit.corners(fromTaps: taps, imageSize: Self.imageSize))

        func norm(_ p: CGPoint) -> CGPoint { CGPoint(x: Double(p.x) / w, y: Double(p.y) / hgt) }
        #expect(isClose(corners.nearRight, norm(Self.quad[0]), 1e-7))
        #expect(isClose(corners.nearLeft, norm(Self.quad[1]), 1e-7))
        #expect(isClose(corners.farLeft, norm(Self.quad[2]), 1e-7))
        #expect(isClose(corners.farRight, norm(Self.quad[3]), 1e-7))

        // The fitted calibration reads the head pin as the center of board 20.
        let geometry = try #require(LaneGeometry(corners: corners, imageSize: Self.imageSize, hand: .right))
        let headPin = geometry.boardFeet(atImage: h.apply(CGPoint(x: 0.5, y: 60)))
        #expect(isClose(headPin.board, 19.5, 1e-5))
        #expect(isClose(headPin.feet, 60, 1e-5))
    }

    @Test("degenerate taps are rejected")
    func degenerateTaps() {
        let colinear = (0..<6).map { CGPoint(x: 0.5, y: 0.1 + Double($0) * 0.1) }
        #expect(LandmarkFit.corners(fromTaps: colinear, imageSize: Self.imageSize) == nil)
        #expect(LandmarkFit.corners(fromTaps: Array(colinear.prefix(5)), imageSize: Self.imageSize) == nil)
    }
}
