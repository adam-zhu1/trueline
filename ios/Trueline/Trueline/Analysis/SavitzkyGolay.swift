import Foundation

/// Savitzky-Golay style local polynomial smoother — port of _savgol_smooth in
/// src/ball_tracking.py. Fits a polynomial in a sliding window and evaluates at
/// the center, preserving hook curvature better than a moving average. Edge
/// regions where the window is asymmetric drop to linear to prevent overshoot.
func savgolSmooth(_ data: [Double], window: Int = 11, polyOrder: Int = 2) -> [Double] {
    let n = data.count
    guard n >= 3 else { return data }
    var w = min(window, n)
    if w % 2 == 0 { w -= 1 }
    w = max(3, w)
    let po = min(polyOrder, w - 1)
    let half = w / 2

    var out = [Double](repeating: 0, count: n)
    for i in 0..<n {
        let lo = max(0, i - half)
        let hi = min(n, i + half + 1)
        let segLen = hi - lo
        var localPo = (segLen < w || i < half || i >= n - half) ? 1 : po
        localPo = min(localPo, segLen - 1)
        if segLen < 2 {
            out[i] = data[i]
            continue
        }
        let ys = Array(data[lo..<hi])
        let coeffs = polyfit(ys: ys, degree: localPo)
        out[i] = polyval(coeffs, at: Double(i - lo))
    }
    return out
}

/// Least-squares polynomial fit of ys against xs = 0..<ys.count, highest degree
/// first (numpy polyfit convention). Solved via normal equations.
private func polyfit(ys: [Double], degree: Int) -> [Double] {
    let n = ys.count
    let terms = degree + 1
    // Precompute power sums Σ x^k for k = 0...2*degree.
    var powerSums = [Double](repeating: 0, count: 2 * degree + 1)
    var rhs = [Double](repeating: 0, count: terms)
    for i in 0..<n {
        let x = Double(i)
        var xp = 1.0
        for k in 0...(2 * degree) {
            powerSums[k] += xp
            if k <= degree {
                rhs[k] += xp * ys[i]
            }
            xp *= x
        }
    }
    var a = [[Double]](repeating: [Double](repeating: 0, count: terms + 1), count: terms)
    for r in 0..<terms {
        for c in 0..<terms {
            a[r][c] = powerSums[r + c]
        }
        a[r][terms] = rhs[r]
    }
    guard let sol = Homography.gaussianSolve(&a, n: terms) else {
        return [ys.reduce(0, +) / Double(n)]
    }
    return sol.reversed()  // highest degree first
}

private func polyval(_ coeffs: [Double], at x: Double) -> Double {
    coeffs.reduce(0) { $0 * x + $1 }
}
