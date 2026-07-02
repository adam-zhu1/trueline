import Foundation

/// Constant-velocity Kalman filter for (x, y) in pixels/frame — port of
/// create_ball_kalman in src/ball_tracking.py, same noise constants.
/// State: [x, y, vx, vy]. Sharp backends change velocity fast; higher process
/// noise on velocity than position avoids over-smoothing hooks.
final class BallKalman {
    private static let qXY = 2.0e-2
    private static let qVel = 0.35
    private static let rMeas = 6.0

    /// State [x, y, vx, vy].
    private(set) var state: [Double]
    /// 4×4 covariance, row-major.
    private var p: [Double]
    private var pPre: [Double]
    private var statePre: [Double]

    init(x: Double, y: Double) {
        state = [x, y, 0, 0]
        p = BallKalman.identity4()
        pPre = p
        statePre = state
    }

    /// Predicted (x, y) for this frame; also advances the prior.
    func predict() -> (x: Double, y: Double) {
        // F = [[1,0,1,0],[0,1,0,1],[0,0,1,0],[0,0,0,1]]
        statePre = [
            state[0] + state[2],
            state[1] + state[3],
            state[2],
            state[3],
        ]
        // P⁻ = F P Fᵀ + Q, expanded for this specific F.
        var n = p
        // F P: row0 += row2, row1 += row3
        for c in 0..<4 {
            n[0 * 4 + c] += n[2 * 4 + c]
            n[1 * 4 + c] += n[3 * 4 + c]
        }
        // (F P) Fᵀ: col0 += col2, col1 += col3
        for r in 0..<4 {
            n[r * 4 + 0] += n[r * 4 + 2]
            n[r * 4 + 1] += n[r * 4 + 3]
        }
        n[0] += Self.qXY
        n[5] += Self.qXY
        n[10] += Self.qVel
        n[15] += Self.qVel
        pPre = n
        return (statePre[0], statePre[1])
    }

    /// Fold in a measurement (standard update with H = [I2 0], R = rMeas·I2).
    func correct(x: Double, y: Double) {
        let s00 = pPre[0] + Self.rMeas
        let s01 = pPre[1]
        let s10 = pPre[4]
        let s11 = pPre[5] + Self.rMeas
        let det = s00 * s11 - s01 * s10
        guard abs(det) > 1e-12 else {
            state = statePre
            p = pPre
            return
        }
        let i00 = s11 / det, i01 = -s01 / det
        let i10 = -s10 / det, i11 = s00 / det
        // K = P⁻ Hᵀ S⁻¹  (4×2); P⁻ Hᵀ is the first two columns of P⁻.
        var k = [Double](repeating: 0, count: 8)
        for r in 0..<4 {
            let a = pPre[r * 4 + 0]
            let b = pPre[r * 4 + 1]
            k[r * 2 + 0] = a * i00 + b * i10
            k[r * 2 + 1] = a * i01 + b * i11
        }
        let rx = x - statePre[0]
        let ry = y - statePre[1]
        state = (0..<4).map { statePre[$0] + k[$0 * 2] * rx + k[$0 * 2 + 1] * ry }
        // P = (I − K H) P⁻; K H has K's columns in cols 0,1 and zeros elsewhere.
        var np = [Double](repeating: 0, count: 16)
        for r in 0..<4 {
            for c in 0..<4 {
                np[r * 4 + c] = pPre[r * 4 + c]
                    - k[r * 2 + 0] * pPre[0 * 4 + c]
                    - k[r * 2 + 1] * pPre[1 * 4 + c]
            }
        }
        p = np
    }

    /// Prediction-only frame (coasting): adopt the prior as the posterior,
    /// matching the Python loop's statePost/errorCovPost assignment.
    func coast() {
        state = statePre
        p = pPre
    }

    private static func identity4() -> [Double] {
        var m = [Double](repeating: 0, count: 16)
        for i in 0..<4 { m[i * 4 + i] = 1 }
        return m
    }
}
