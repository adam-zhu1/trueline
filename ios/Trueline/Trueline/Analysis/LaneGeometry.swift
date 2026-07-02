import CoreGraphics
import Foundation

/// Lane coordinate math for a 4-corner calibration (port of the homography parts
/// of src/ball_tracking.py + calibration.py). Unlike the Python prototype the
/// camera angle is arbitrary, so every measure (feet down-lane, board, crossing
/// tests) goes through the homography — no horizontal-line assumptions.
///
/// Lane space: t_across 0 = right-gutter corner, 1 = left-gutter corner;
/// feet 0 = foul line, 60 = pin line. Board 1 is the outside board for both
/// hands (right gutter for right-handers).
struct LaneGeometry {
    enum Hand { case right, left }

    static let laneLengthFeet = 60.0
    static let laneWidthInches = 41.5
    static let dotDistanceFeet = 6.0
    /// Where Specto reads entry board — just ahead of the head pin.
    static let entryBoardFeet = 59.5
    /// Detections may sit slightly outside an imperfect quad; accept centers up
    /// to this far outside the lane polygon (pixels, matches Python).
    static let laneMarginPx = 22.0

    let hand: Hand
    /// Image pixels → (t_across, feet).
    private let toLane: Homography
    /// (t_across, feet) → image pixels.
    private let toImage: Homography
    /// Lane quad in image pixels: foulRight, foulLeft, pinLeft, pinRight.
    let quad: [CGPoint]
    /// Pixels per foot near the foul line (drives the association gate).
    let pixelsPerFoot: Double

    init?(corners: LaneCorners, imageSize: CGSize, hand: Hand) {
        let w = imageSize.width
        let h = imageSize.height
        let foulRight = CGPoint(x: corners.nearRight.x * w, y: corners.nearRight.y * h)
        let foulLeft = CGPoint(x: corners.nearLeft.x * w, y: corners.nearLeft.y * h)
        let pinLeft = CGPoint(x: corners.farLeft.x * w, y: corners.farLeft.y * h)
        let pinRight = CGPoint(x: corners.farRight.x * w, y: corners.farRight.y * h)
        quad = [foulRight, foulLeft, pinLeft, pinRight]

        let lane = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: Self.laneLengthFeet),
            CGPoint(x: 0, y: Self.laneLengthFeet),
        ]
        guard let forward = Homography(from: quad, to: lane),
              let backward = Homography(from: lane, to: quad)
        else { return nil }
        toLane = forward
        toImage = backward
        self.hand = hand

        let p0 = backward.apply(CGPoint(x: 0.5, y: 0))
        let p6 = backward.apply(CGPoint(x: 0.5, y: Self.dotDistanceFeet))
        pixelsPerFoot = Double(hypot(p6.x - p0.x, p6.y - p0.y)) / Self.dotDistanceFeet
    }

    /// (board 1–39, feet 0–60) of an image pixel; both clamped like the prototype.
    func boardFeet(atImage p: CGPoint) -> (board: Double, feet: Double) {
        let lane = toLane.apply(p)
        let t = min(max(Double(lane.x), 0), 1)
        let feet = min(max(Double(lane.y), 0), Self.laneLengthFeet)
        let board: Double
        switch hand {
        case .right: board = 1.0 + t * 38.0
        case .left: board = 1.0 + (1.0 - t) * 38.0
        }
        return (min(max(board, 1), 39), feet)
    }

    /// Feet down-lane without clamping across (used for far-lane confidence logic).
    func feet(atImage p: CGPoint) -> Double {
        min(max(Double(toLane.apply(p).y), 0), Self.laneLengthFeet)
    }

    func imagePoint(tAcross: Double, feet: Double) -> CGPoint {
        toImage.apply(CGPoint(x: tAcross, y: feet))
    }

    /// Signed distance to the lane quad: positive inside, negative outside
    /// (port of cv2.pointPolygonTest with measureDist).
    func signedDistanceToLane(_ p: CGPoint) -> Double {
        var inside = false
        var minDist = Double.greatestFiniteMagnitude
        var j = quad.count - 1
        for i in 0..<quad.count {
            let a = quad[j]
            let b = quad[i]
            if (b.y > p.y) != (a.y > p.y),
               Double(p.x) < Double(b.x) + Double(a.x - b.x) * Double(p.y - b.y) / Double(a.y - b.y) {
                inside.toggle()
            }
            minDist = min(minDist, Self.distanceToSegment(p, a, b))
            j = i
        }
        return inside ? minDist : -minDist
    }

    /// Local lane pixel width / foul-line pixel width at the given image point's
    /// depth. Pixel velocity shrinks by this factor down-lane, so the Kalman
    /// association gate must shrink with it.
    func laneWidthScale(atImage p: CGPoint) -> Double {
        let ft = feet(atImage: p)
        let l = imagePoint(tAcross: 0, feet: ft)
        let r = imagePoint(tAcross: 1, feet: ft)
        let f0 = imagePoint(tAcross: 0, feet: 0)
        let f1 = imagePoint(tAcross: 1, feet: 0)
        let wHere = Double(hypot(l.x - r.x, l.y - r.y))
        let wFoul = Double(hypot(f0.x - f1.x, f0.y - f1.y))
        guard wFoul > 1e-6 else { return 1.0 }
        return min(max(wHere / wFoul, 0.2), 1.0)
    }

    var laneCentroid: CGPoint {
        CGPoint(
            x: quad.map(\.x).reduce(0, +) / 4,
            y: quad.map(\.y).reduce(0, +) / 4
        )
    }

    private static func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        let abx = Double(b.x - a.x), aby = Double(b.y - a.y)
        let apx = Double(p.x - a.x), apy = Double(p.y - a.y)
        let len2 = abx * abx + aby * aby
        let t = len2 > 0 ? min(max((apx * abx + apy * aby) / len2, 0), 1) : 0
        let dx = apx - t * abx, dy = apy - t * aby
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// USBC arrow V: center arrow (board 20) at 16 ft, outer arrows (5 & 35) at 12 ft.
func arrowFeet(atBoard board: Double) -> Double {
    16.0 - abs(board - 20.0) * (4.0 / 15.0)
}

/// 3×3 projective transform (port of cv2.getPerspectiveTransform).
struct Homography {
    // Row-major 3×3.
    let m: [Double]

    init?(from src: [CGPoint], to dst: [CGPoint]) {
        guard src.count == 4, dst.count == 4 else { return nil }
        // Solve the standard 8×8 system for h00..h21 (h22 = 1).
        var a = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let x = Double(src[i].x), y = Double(src[i].y)
            let u = Double(dst[i].x), v = Double(dst[i].y)
            a[i * 2] = [x, y, 1, 0, 0, 0, -x * u, -y * u, u]
            a[i * 2 + 1] = [0, 0, 0, x, y, 1, -x * v, -y * v, v]
        }
        guard let h = Homography.gaussianSolve(&a, n: 8) else { return nil }
        m = h + [1.0]
    }

    func apply(_ p: CGPoint) -> CGPoint {
        let x = Double(p.x), y = Double(p.y)
        let w = m[6] * x + m[7] * y + m[8]
        guard abs(w) > 1e-12 else { return .zero }
        return CGPoint(
            x: (m[0] * x + m[1] * y + m[2]) / w,
            y: (m[3] * x + m[4] * y + m[5]) / w
        )
    }

    /// Gaussian elimination with partial pivoting on an n×(n+1) augmented matrix.
    static func gaussianSolve(_ a: inout [[Double]], n: Int) -> [Double]? {
        for col in 0..<n {
            var pivot = col
            for row in (col + 1)..<n where abs(a[row][col]) > abs(a[pivot][col]) {
                pivot = row
            }
            guard abs(a[pivot][col]) > 1e-12 else { return nil }
            a.swapAt(col, pivot)
            for row in 0..<n where row != col {
                let f = a[row][col] / a[col][col]
                for k in col...n {
                    a[row][k] -= f * a[col][k]
                }
            }
        }
        return (0..<n).map { a[$0][n] / a[$0][$0] }
    }
}
