import CoreGraphics
import Foundation

/// Swift port of the gutter-line lane auto-detect prototype
/// (experiments/lane_autodetect.py). The two gutter channels are the strongest,
/// longest near-linear edges converging toward the pins: find them with
/// Canny + probabilistic Hough (implemented here — Apple ships neither), keep
/// the pair bracketing the frame's horizontal center, and intersect with a
/// near row (foul end) and far row (pin end) for the four corners.
///
/// Parameters mirror the prototype: blur 5×5, Canny 40/120, Hough threshold 80,
/// min length 0.18·h, max gap 0.04·h, steep-angle cutoff 35°, near row 0.92·h,
/// far row at 18% of near gutter separation.
enum LaneAutoDetector {

    struct PixelCorners {
        var foulLeft: CGPoint
        var foulRight: CGPoint
        var pinLeft: CGPoint
        var pinRight: CGPoint
    }

    /// Corners normalized to 0–1, ready to seed the calibration UI.
    static func detectLaneCorners(in image: CGImage) -> LaneCorners? {
        guard let c = detectPixelCorners(in: image) else { return nil }
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        return LaneCorners(
            farLeft: CGPoint(x: c.pinLeft.x / w, y: c.pinLeft.y / h),
            farRight: CGPoint(x: c.pinRight.x / w, y: c.pinRight.y / h),
            nearRight: CGPoint(x: c.foulRight.x / w, y: c.foulRight.y / h),
            nearLeft: CGPoint(x: c.foulLeft.x / w, y: c.foulLeft.y / h)
        )
    }

    static func detectPixelCorners(in image: CGImage) -> PixelCorners? {
        let w = image.width
        let h = image.height
        return corners(from: detectSegments(in: image), width: w, height: h)
    }

    /// Raw Hough segments — exposed for debugging/visualization.
    static func detectSegments(in image: CGImage) -> [(Int, Int, Int, Int)] {
        let w = image.width
        let h = image.height
        guard w > 16, h > 16 else { return [] }

        let gray = grayscale(image, width: w, height: h)
        let blurred = gaussianBlur5x5(gray, width: w, height: h)
        let edges = canny(blurred, width: w, height: h, low: 40, high: 120)
        return houghSegmentsProbabilistic(
            edges: edges, width: w, height: h,
            threshold: 80,
            minLineLength: Int(0.18 * Double(h)),
            maxLineGap: Int(0.04 * Double(h))
        )
    }

    // MARK: - Line selection (port of detect_corners)

    private struct Line {
        var a: Double      // x = a*y + b
        var b: Double
        var length: Double
        var xBot: Double   // x at y = h
        var yBot: Double   // bottom-most extent of the segment
    }

    private static func corners(from segments: [(Int, Int, Int, Int)], width w: Int, height h: Int) -> PixelCorners? {
        let hd = Double(h)
        let cx = Double(w) / 2

        var lines: [Line] = []
        for (x1, y1, x2, y2) in segments {
            // Video borders produce strong artificial vertical edges; a segment
            // hugging the frame edge is never a gutter.
            let margin = 3
            if (x1 <= margin && x2 <= margin) || (x1 >= w - 1 - margin && x2 >= w - 1 - margin) {
                continue
            }
            let dy = Double(y2 - y1)
            guard abs(dy) >= 1 else { continue }
            let a = Double(x2 - x1) / dy
            let b = Double(x1) - a * Double(y1)
            let angle = atan2(abs(dy), abs(Double(x2 - x1))) * 180 / .pi
            guard angle >= 35 else { continue }  // too horizontal to be a gutter
            let length = (Double(x2 - x1) * Double(x2 - x1) + dy * dy).squareRoot()
            lines.append(Line(
                a: a, b: b, length: length,
                xBot: a * hd + b,
                yBot: Double(max(y1, y2))
            ))
        }

        // Left gutter crosses the bottom left of center leaning right going up;
        // right gutter mirrors it. Small slope tolerance matches the prototype.
        let lefts = lines.filter { $0.xBot < cx && $0.a <= 0.15 }
        let rights = lines.filter { $0.xBot > cx && $0.a >= -0.15 }
        guard !lefts.isEmpty, !rights.isEmpty else { return nil }

        // Prefer long lines whose bottom is near center (subject lane brackets center).
        func score(_ l: Line) -> Double {
            let prox = 1.0 - min(1.0, abs(l.xBot - cx) / (0.5 * Double(w)))
            return l.length * (0.5 + prox)
        }
        let left = lefts.max { score($0) < score($1) }!
        let right = rights.max { score($0) < score($1) }!

        func xAt(_ l: Line, _ y: Double) -> Double { l.a * y + l.b }

        // Foul row: where the gutter edges actually end at the bottom — an
        // assumed fraction of the frame plants the foul corners in the UI
        // chrome of screen recordings, 500 px off. Colinear segments (the
        // gutter split by compression) extend the chosen line's reach.
        func bottomReach(of chosen: Line) -> Double {
            var reach = chosen.yBot
            for l in lines
            where abs(l.a - chosen.a) <= 0.12 && abs(xAt(l, l.yBot) - xAt(chosen, l.yBot)) <= 14 {
                reach = max(reach, l.yBot)
            }
            return reach
        }
        let yNear = min(max(max(bottomReach(of: left), bottomReach(of: right)), 0.30 * hd), 0.96 * hd)

        let sepNear = abs(xAt(right, yNear) - xAt(left, yNear))
        // Lanes aren't slivers; a tiny separation means we latched onto the
        // wrong pair of edges.
        guard sepNear > 0.08 * Double(w) else { return nil }

        // Far row: where the gutters have converged to ~18% of the near separation
        // (approx the pin deck; avoids running to the vanishing point).
        var yFar: Double?
        let steps = 200
        for i in 0..<steps {
            let y = yNear * (1 - Double(i) / Double(steps - 1))
            if abs(xAt(right, y) - xAt(left, y)) <= 0.18 * sepNear {
                yFar = y
                break
            }
        }
        // No convergence inside the frame → not a usable lane read. A
        // degenerate quad silently poisons every metric, so fail and let the
        // calibration screen show the honest drag-the-corners default.
        guard let yFar, yNear - yFar >= 0.15 * hd else { return nil }

        return PixelCorners(
            foulLeft: CGPoint(x: xAt(left, yNear), y: yNear),
            foulRight: CGPoint(x: xAt(right, yNear), y: yNear),
            pinLeft: CGPoint(x: xAt(left, yFar), y: yFar),
            pinRight: CGPoint(x: xAt(right, yFar), y: yFar)
        )
    }

    // MARK: - Grayscale + blur

    private static func grayscale(_ image: CGImage, width w: Int, height h: Int) -> [UInt8] {
        // BT.601 luma on the raw sRGB bytes, matching OpenCV's COLOR_BGR2GRAY
        // (a color-managed gray conversion shifts edge strengths noticeably).
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        rgba.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var gray = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let r = Double(rgba[i * 4])
            let g = Double(rgba[i * 4 + 1])
            let b = Double(rgba[i * 4 + 2])
            gray[i] = UInt8(min(255, (0.299 * r + 0.587 * g + 0.114 * b).rounded()))
        }
        return gray
    }

    private static func gaussianBlur5x5(_ src: [UInt8], width w: Int, height h: Int) -> [Float] {
        // OpenCV GaussianBlur(ksize 5, sigma 0) → sigma 1.1; same normalized taps.
        let k: [Float] = {
            let sigma: Float = 1.1
            var taps = (-2...2).map { expf(-Float($0 * $0) / (2 * sigma * sigma)) }
            let sum = taps.reduce(0, +)
            for i in taps.indices { taps[i] /= sum }
            return taps
        }()

        var tmp = [Float](repeating: 0, count: w * h)
        var dst = [Float](repeating: 0, count: w * h)
        // Horizontal pass (clamped borders).
        for y in 0..<h {
            let row = y * w
            for x in 0..<w {
                var acc: Float = 0
                for t in -2...2 {
                    let xx = min(max(x + t, 0), w - 1)
                    acc += k[t + 2] * Float(src[row + xx])
                }
                tmp[row + x] = acc
            }
        }
        // Vertical pass.
        for y in 0..<h {
            for x in 0..<w {
                var acc: Float = 0
                for t in -2...2 {
                    let yy = min(max(y + t, 0), h - 1)
                    acc += k[t + 2] * tmp[yy * w + x]
                }
                dst[y * w + x] = acc
            }
        }
        return dst
    }

    // MARK: - Canny (Sobel 3×3, L1 magnitude, NMS, hysteresis)

    private static func canny(_ src: [Float], width w: Int, height h: Int, low: Float, high: Float) -> [UInt8] {
        var gx = [Float](repeating: 0, count: w * h)
        var gy = [Float](repeating: 0, count: w * h)
        var mag = [Float](repeating: 0, count: w * h)

        for y in 1..<(h - 1) {
            let r0 = (y - 1) * w, r1 = y * w, r2 = (y + 1) * w
            for x in 1..<(w - 1) {
                let tl = src[r0 + x - 1], tc = src[r0 + x], tr = src[r0 + x + 1]
                let ml = src[r1 + x - 1], mr = src[r1 + x + 1]
                let bl = src[r2 + x - 1], bc = src[r2 + x], br = src[r2 + x + 1]
                let dx = (tr + 2 * mr + br) - (tl + 2 * ml + bl)
                let dy = (bl + 2 * bc + br) - (tl + 2 * tc + tr)
                gx[r1 + x] = dx
                gy[r1 + x] = dy
                mag[r1 + x] = abs(dx) + abs(dy)  // L1, as OpenCV's default
            }
        }

        // Non-maximum suppression along the gradient direction (4 sectors).
        var nms = [UInt8](repeating: 0, count: w * h)  // 1 = weak, 2 = strong
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let m = mag[i]
                guard m >= low else { continue }
                var angle = atan2(gy[i], gx[i]) * 180 / .pi
                if angle < 0 { angle += 180 }
                let (n1, n2): (Float, Float)
                switch angle {
                case ..<22.5, 157.5...:
                    (n1, n2) = (mag[i - 1], mag[i + 1])
                case ..<67.5:
                    (n1, n2) = (mag[i - w - 1], mag[i + w + 1])
                case ..<112.5:
                    (n1, n2) = (mag[i - w], mag[i + w])
                default:
                    (n1, n2) = (mag[i - w + 1], mag[i + w - 1])
                }
                guard m >= n1, m >= n2 else { continue }
                nms[i] = m >= high ? 2 : 1
            }
        }

        // Hysteresis: keep weak pixels only when connected to a strong one.
        var edges = [UInt8](repeating: 0, count: w * h)
        var stack: [Int] = []
        for i in 0..<(w * h) where nms[i] == 2 {
            stack.append(i)
            edges[i] = 1
        }
        let offsets = [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]
        while let i = stack.popLast() {
            for o in offsets {
                let j = i + o
                if j >= 0, j < w * h, nms[j] != 0, edges[j] == 0 {
                    edges[j] = 1
                    stack.append(j)
                }
            }
        }
        return edges
    }

    // MARK: - Probabilistic Hough (port of OpenCV HoughLinesProbabilistic)

    private static func houghSegmentsProbabilistic(
        edges: [UInt8], width w: Int, height h: Int,
        threshold: Int, minLineLength: Int, maxLineGap: Int
    ) -> [(Int, Int, Int, Int)] {
        let numAngle = 180
        let numRho = 2 * (w + h) + 1
        let rhoOffset = (numRho - 1) / 2
        var cosTab = [Double](repeating: 0, count: numAngle)
        var sinTab = [Double](repeating: 0, count: numAngle)
        for n in 0..<numAngle {
            let a = Double(n) * .pi / 180
            cosTab[n] = cos(a)
            sinTab[n] = sin(a)
        }

        var mask = edges
        var points: [(Int, Int)] = []
        for y in 0..<h {
            for x in 0..<w where edges[y * w + x] != 0 {
                points.append((x, y))
            }
        }
        guard !points.isEmpty else { return [] }

        var accum = [Int32](repeating: 0, count: numAngle * numRho)
        var rng = SplitMix64(seed: 0x74727565)  // fixed seed → reproducible runs
        var count = points.count
        var result: [(Int, Int, Int, Int)] = []

        while count > 0 {
            let idx = Int(rng.next() % UInt64(count))
            let (px, py) = points[idx]
            points[idx] = points[count - 1]
            count -= 1

            // Skip if already claimed by an earlier segment.
            guard mask[py * w + px] != 0 else { continue }

            // Vote all angles for this point, tracking the best bin.
            var maxVal = Int32(threshold - 1)
            var maxN = -1
            for n in 0..<numAngle {
                let r = Int((Double(px) * cosTab[n] + Double(py) * sinTab[n]).rounded()) + rhoOffset
                accum[n * numRho + r] += 1
                if accum[n * numRho + r] > maxVal {
                    maxVal = accum[n * numRho + r]
                    maxN = n
                }
            }
            guard maxN >= 0 else { continue }

            // Walk along the candidate line in both directions, tolerating gaps,
            // to find the segment through this point.
            let cosA = cosTab[maxN], sinA = sinTab[maxN]
            let shift = 16
            var dx0: Int, dy0: Int
            var xFlag: Bool
            // Along-line direction for a line with normal angle θ is (sinθ, -cosθ),
            // normalized so the dominant component steps by exactly ±1 pixel.
            if abs(sinA) > abs(cosA) {
                xFlag = true
                dx0 = sinA > 0 ? 1 : -1
                dy0 = Int((-cosA * Double(1 << shift) / abs(sinA)).rounded())
            } else {
                xFlag = false
                dy0 = cosA > 0 ? 1 : -1
                dx0 = Int((-sinA * Double(1 << shift) / abs(cosA)).rounded())
            }

            var lineEnds = [(Int, Int)](repeating: (px, py), count: 2)
            for k in 0..<2 {
                var x = xFlag ? px : (px << shift) + (1 << (shift - 1))
                var y = xFlag ? (py << shift) + (1 << (shift - 1)) : py
                let dx = k == 0 ? dx0 : -dx0
                let dy = k == 0 ? dy0 : -dy0
                var gap = 0
                while true {
                    let x1 = xFlag ? x : x >> shift
                    let y1 = xFlag ? y >> shift : y
                    guard x1 >= 0, x1 < w, y1 >= 0, y1 < h else { break }
                    if mask[y1 * w + x1] != 0 {
                        gap = 0
                        lineEnds[k] = (x1, y1)
                    } else {
                        gap += 1
                        if gap > maxLineGap { break }
                    }
                    x += dx
                    y += dy
                }
            }

            let goodLine = abs(lineEnds[1].0 - lineEnds[0].0) >= minLineLength
                || abs(lineEnds[1].1 - lineEnds[0].1) >= minLineLength

            // Second pass: clear the walked pixels from the mask; if the segment
            // is kept, also cancel their votes (mirrors OpenCV exactly).
            for k in 0..<2 {
                var x = xFlag ? px : (px << shift) + (1 << (shift - 1))
                var y = xFlag ? (py << shift) + (1 << (shift - 1)) : py
                let dx = k == 0 ? dx0 : -dx0
                let dy = k == 0 ? dy0 : -dy0
                while true {
                    let x1 = xFlag ? x : x >> shift
                    let y1 = xFlag ? y >> shift : y
                    if mask[y1 * w + x1] != 0 {
                        if goodLine {
                            for n in 0..<numAngle {
                                let r = Int((Double(x1) * cosTab[n] + Double(y1) * sinTab[n]).rounded()) + rhoOffset
                                accum[n * numRho + r] -= 1
                            }
                        }
                        mask[y1 * w + x1] = 0
                    }
                    if x1 == lineEnds[k].0 && y1 == lineEnds[k].1 { break }
                    x += dx
                    y += dy
                }
            }

            if goodLine {
                result.append((lineEnds[0].0, lineEnds[0].1, lineEnds[1].0, lineEnds[1].1))
            }
        }
        return result
    }
}

/// Small seedable RNG (SplitMix64) so detection is reproducible run to run.
private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
