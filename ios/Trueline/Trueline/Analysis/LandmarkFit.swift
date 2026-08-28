import CoreGraphics
import Foundation

/// The six easy tap targets of the v1.1 calibration flow and the least-squares
/// fit that turns them into lane corners (port of experiments/calibration_v11).
/// Tap targets are recognizable objects, not abstract corners: the harness
/// Monte Carlo measured 1.8 boards median entry error for these six taps alone
/// vs 3.0 for today's four corners, and 0.5 after the overlay refine step.
enum LandmarkFit {
    /// One guided tap: where it sits on the lane, and what to tell the user.
    struct Target {
        /// Lane coords: x 0 = right gutter, 1 = left gutter; y in feet.
        let lane: CGPoint
        let hint: String
    }

    /// Arrow depths are house-specific; the alley references fitted apex
    /// 14.5-15.2 ft with a 0.5 ft step, well inside USBC's 12-16 ft band.
    /// Nominal values sit on the measured cluster; the refine step absorbs
    /// the per-house difference.
    private static let arrowApexFeet = 15.0
    private static let arrowOuterFeet = 13.5

    private static func boardX(_ board: Double) -> Double {
        (board - 0.5) / 39.0
    }

    /// Tap order walks the frame bottom to top: near foul corners first
    /// (big, forgiving), then the arrow row, then the head pin.
    static let targets: [Target] = [
        Target(lane: CGPoint(x: 0, y: 0),
               hint: "Tap where the foul line meets the right gutter."),
        Target(lane: CGPoint(x: 1, y: 0),
               hint: "Tap where the foul line meets the left gutter."),
        Target(lane: CGPoint(x: boardX(35), y: arrowOuterFeet),
               hint: "Tap the leftmost arrow."),
        Target(lane: CGPoint(x: boardX(20), y: arrowApexFeet),
               hint: "Tap the middle arrow."),
        Target(lane: CGPoint(x: boardX(5), y: arrowOuterFeet),
               hint: "Tap the rightmost arrow."),
        Target(lane: CGPoint(x: boardX(20), y: 60),
               hint: "Tap the base of the head pin."),
    ]

    /// Pin spot positions for the overlay: (feet, boards) per rack row.
    /// Aligning the drawn spots with the real rack is the refine gesture the
    /// Monte Carlo validated; the rack is the only far-lane target that is
    /// not a specular trap.
    static let pinRows: [(feet: Double, boards: [Double])] = [
        (60.00, [20]),
        (60.87, [14.36, 25.64]),
        (61.73, [8.72, 20, 31.28]),
        (62.60, [3.08, 14.36, 25.64, 36.92]),
    ]

    /// Fits taps (normalized image coords, same space as LaneCorners) to the
    /// targets' lane coords and returns the implied lane corners. nil when the
    /// taps are degenerate (e.g. colinear) and no homography exists.
    static func corners(fromTaps taps: [CGPoint], imageSize: CGSize) -> LaneCorners? {
        guard taps.count == targets.count, imageSize.width > 0, imageSize.height > 0 else { return nil }
        let px = taps.map { CGPoint(x: $0.x * imageSize.width, y: $0.y * imageSize.height) }
        guard let toLane = Homography(leastSquaresFrom: px, to: targets.map(\.lane)),
              let toImage = toLane.inverted()
        else { return nil }

        func normalized(_ lane: CGPoint) -> CGPoint {
            let p = toImage.apply(lane)
            return CGPoint(x: p.x / imageSize.width, y: p.y / imageSize.height)
        }
        let corners = LaneCorners(
            farLeft: normalized(CGPoint(x: 1, y: 60)),
            farRight: normalized(CGPoint(x: 0, y: 60)),
            nearRight: normalized(CGPoint(x: 0, y: 0)),
            nearLeft: normalized(CGPoint(x: 1, y: 0))
        )
        // A wild tap set can still produce a homography whose corners are far
        // outside the frame; reject those so the refine screen starts sane.
        let all = [corners.farLeft, corners.farRight, corners.nearRight, corners.nearLeft]
        guard all.allSatisfy({ $0.x > -0.5 && $0.x < 1.5 && $0.y > -0.5 && $0.y < 1.5 }) else { return nil }
        return corners
    }
}

extension Homography {
    /// Least-squares homography from N >= 4 correspondences: Hartley-normalized
    /// DLT, smallest eigenvector of AᵀA by Jacobi rotations (the method behind
    /// cv2.findHomography with method 0, which the harness experiments used).
    init?(leastSquaresFrom src: [CGPoint], to dst: [CGPoint]) {
        guard src.count == dst.count, src.count >= 4,
              let (ns, ts) = Homography.hartleyNormalize(src),
              let (nd, td) = Homography.hartleyNormalize(dst)
        else { return nil }

        var ata = [Double](repeating: 0, count: 81)
        for i in 0..<ns.count {
            let x = ns[i].0, y = ns[i].1
            let u = nd[i].0, v = nd[i].1
            let row1: [Double] = [x, y, 1, 0, 0, 0, -x * u, -y * u, -u]
            let row2: [Double] = [0, 0, 0, x, y, 1, -x * v, -y * v, -v]
            for row in [row1, row2] {
                for a in 0..<9 {
                    for b in 0..<9 {
                        ata[a * 9 + b] += row[a] * row[b]
                    }
                }
            }
        }
        guard let h = Homography.smallestEigenvector(ata, n: 9) else { return nil }

        // Denormalize: H = Td⁻¹ · Hn · Ts.
        let hn = Homography(m: h)
        guard let tdInv = Homography(m: td).inverted() else { return nil }
        var full = tdInv.multiplied(by: hn).multiplied(by: Homography(m: ts)).m
        guard abs(full[8]) > 1e-12 else { return nil }
        for i in 0..<9 {
            full[i] /= full[8]
        }
        self.init(m: full)
    }

    init(m: [Double]) {
        self.m = m
    }

    /// Inverse via the adjugate; nil when singular.
    func inverted() -> Homography? {
        let a = m
        let det = a[0] * (a[4] * a[8] - a[5] * a[7])
            - a[1] * (a[3] * a[8] - a[5] * a[6])
            + a[2] * (a[3] * a[7] - a[4] * a[6])
        guard abs(det) > 1e-12 else { return nil }
        let inv = [
            (a[4] * a[8] - a[5] * a[7]) / det,
            (a[2] * a[7] - a[1] * a[8]) / det,
            (a[1] * a[5] - a[2] * a[4]) / det,
            (a[5] * a[6] - a[3] * a[8]) / det,
            (a[0] * a[8] - a[2] * a[6]) / det,
            (a[2] * a[3] - a[0] * a[5]) / det,
            (a[3] * a[7] - a[4] * a[6]) / det,
            (a[1] * a[6] - a[0] * a[7]) / det,
            (a[0] * a[4] - a[1] * a[3]) / det,
        ]
        return Homography(m: inv)
    }

    func multiplied(by other: Homography) -> Homography {
        var out = [Double](repeating: 0, count: 9)
        for r in 0..<3 {
            for c in 0..<3 {
                for k in 0..<3 {
                    out[r * 3 + c] += m[r * 3 + k] * other.m[k * 3 + c]
                }
            }
        }
        return Homography(m: out)
    }

    /// Centroid to origin, mean distance to √2; returns points + 3×3 transform.
    private static func hartleyNormalize(_ pts: [CGPoint]) -> ([(Double, Double)], [Double])? {
        let n = Double(pts.count)
        let cx = pts.reduce(0.0) { $0 + Double($1.x) } / n
        let cy = pts.reduce(0.0) { $0 + Double($1.y) } / n
        let meanDist = pts.reduce(0.0) { $0 + hypot(Double($1.x) - cx, Double($1.y) - cy) } / n
        guard meanDist > 1e-12 else { return nil }
        let s = 2.0.squareRoot() / meanDist
        let normalized = pts.map { ((Double($0.x) - cx) * s, (Double($0.y) - cy) * s) }
        return (normalized, [s, 0, -s * cx, 0, s, -s * cy, 0, 0, 1])
    }

    /// Eigenvector of the smallest eigenvalue of a symmetric n×n matrix, by
    /// cyclic Jacobi rotations. n is tiny (9), so no numerics library needed.
    private static func smallestEigenvector(_ matrix: [Double], n: Int) -> [Double]? {
        var a = matrix
        var v = [Double](repeating: 0, count: n * n)
        for i in 0..<n {
            v[i * n + i] = 1
        }
        for _ in 0..<100 {
            var off = 0.0
            for p in 0..<n {
                for q in (p + 1)..<n {
                    off += a[p * n + q] * a[p * n + q]
                }
            }
            if off < 1e-20 { break }
            for p in 0..<n {
                for q in (p + 1)..<n {
                    let apq = a[p * n + q]
                    guard abs(apq) > 1e-30 else { continue }
                    let theta = (a[q * n + q] - a[p * n + p]) / (2 * apq)
                    let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + (theta * theta + 1).squareRoot())
                    let c = 1 / (t * t + 1).squareRoot()
                    let s = t * c
                    for k in 0..<n {
                        let akp = a[k * n + p], akq = a[k * n + q]
                        a[k * n + p] = c * akp - s * akq
                        a[k * n + q] = s * akp + c * akq
                    }
                    for k in 0..<n {
                        let apk = a[p * n + k], aqk = a[q * n + k]
                        a[p * n + k] = c * apk - s * aqk
                        a[q * n + k] = s * apk + c * aqk
                    }
                    for k in 0..<n {
                        let vkp = v[k * n + p], vkq = v[k * n + q]
                        v[k * n + p] = c * vkp - s * vkq
                        v[k * n + q] = s * vkp + c * vkq
                    }
                }
            }
        }
        var best = 0
        for i in 1..<n where a[i * n + i] < a[best * n + best] {
            best = i
        }
        return (0..<n).map { v[$0 * n + best] }
    }
}
