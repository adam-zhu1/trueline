import AVFoundation
import CoreGraphics
import CoreML
import Foundation

/// One analyzed throw — the numbers the Python prototype prints in its shot
/// summary, plus the smoothed path for the lane view.
struct ShotResult {
    var speedMph: Double?
    var arrowBoard: Double?
    var breakpointBoard: Double?
    var breakpointFeet: Double?
    var entryAngleDegrees: Double?
    /// Smoothed (board, feet) samples for drawing the lane-view path.
    var path: [(board: Double, feet: Double)]
    /// Smoothed ball-contact points in display-oriented normalized coordinates,
    /// for drawing the trail over the source video.
    var videoPath: [CGPoint]
    /// Video dimensions as displayed (orientation applied).
    var videoDisplaySize: CGSize
    var trackedFrames: Int
}

/// Offline analysis of a recorded throw — port of track_ball in
/// src/ball_tracking.py, YOLO branch only (Core ML replaces MOG2+Hough), with
/// all crossing logic in homography feet instead of pixel rows so it works for
/// any camera angle.
struct ShotAnalyzer {
    var detector: BallDetector
    var corners: LaneCorners
    var hand: LaneGeometry.Hand

    private struct Sample {
        var x: Double
        var y: Double
        var frame: Int
        var radius: Double
    }

    func analyze(videoURL: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws -> ShotResult {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw AnalyzerError.noVideoTrack
        }
        let fps = try await Double(track.load(.nominalFrameRate))
        let transform = try await track.load(.preferredTransform)
        let naturalSize = try await track.load(.naturalSize)
        let duration = try await asset.load(.duration).seconds
        let orientation = Self.orientation(from: transform)
        // Corners were placed on the display-oriented frame; convert into the
        // raw buffer space every pixel computation uses.
        let rawCorners = Self.cornersToRaw(corners, orientation: orientation)
        guard let geometry = LaneGeometry(corners: rawCorners, imageSize: naturalSize, hand: hand) else {
            throw AnalyzerError.badCalibration
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        reader.add(output)
        reader.startReading()

        let fpsSafe = max(fps.isFinite && fps > 0.5 ? fps : 30.0, 1.0)
        let totalFrames = max(1, Int(duration * fpsSafe))

        // --- Tracking state (names follow the Python loop) ---
        var positions: [Sample] = []
        var kalman: BallKalman?
        var lastR = 30.0
        var noMeasStreak = 0
        let maxPredOnlyFrames = 75
        // Past 45 ft a coasting prediction paints a straight line exactly where
        // the hook matters; a short cap there corrupts far less path.
        let farCoastCap = 12
        var maxJumpPx = geometry.pixelsPerFoot * 72.0 / fpsSafe
        maxJumpPx = min(max(maxJumpPx, 32), 320)
        var lastMeasSmooth: (Double, Double)?
        var framesSinceTrack = 0
        var trackFinished = false
        var dotCrossedFrame: Int?
        var frameNumber = 0
        let laneCentroid = geometry.laneCentroid

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            if trackFinished { continue }
            frameNumber += 1
            if frameNumber % 10 == 0 {
                progress?(min(Double(frameNumber) / Double(totalFrames), 1.0))
            }

            let candidates = detector.candidates(
                in: pixelBuffer, orientation: orientation, geometry: geometry
            )

            var measurement: BallDetector.Candidate?
            var coastPred: (x: Double, y: Double)?

            if let kf = kalman {
                let pred = kf.predict()
                coastPred = pred
                if let nearest = candidates.min(by: {
                    Self.dist2($0, x: pred.x, y: pred.y) < Self.dist2($1, x: pred.x, y: pred.y)
                }) {
                    let d = Self.dist2(nearest, x: pred.x, y: pred.y).squareRoot()
                    // Widen gate early (release noise) and later (hook lag).
                    let jumpScale: Double
                    if frameNumber <= 140 {
                        jumpScale = 1.55
                    } else if let dc = dotCrossedFrame, frameNumber >= dc {
                        jumpScale = 1.48
                    } else {
                        jumpScale = 1.32
                    }
                    let scale = geometry.laneWidthScale(atImage: CGPoint(x: pred.x, y: pred.y))
                    let jumpOK = max(28.0, maxJumpPx * jumpScale * scale)
                    if d <= jumpOK { measurement = nearest }
                }
            } else if !candidates.isEmpty {
                // First lock: largest ball-sized candidate nearest the lane center.
                let ballish = candidates.filter { $0.radius >= 10 && $0.radius <= 58 }
                let pool = ballish.isEmpty ? candidates : ballish
                let cx = Double(laneCentroid.x)
                let cy = Double(laneCentroid.y)
                measurement = pool.min(by: {
                    Self.dist2($0, x: cx, y: cy) < Self.dist2($1, x: cx, y: cy)
                })
            }

            var sx: Double?
            var sy: Double?

            if let m = measurement {
                noMeasStreak = 0
                var (rx, ry, rr) = Self.refineCenter(
                    pixelBuffer: pixelBuffer, x: m.x, y: m.y, r: m.radius
                )
                if let last = lastMeasSmooth, framesSinceTrack > 7 {
                    let a = 0.42
                    rx = a * rx + (1 - a) * last.0
                    ry = a * ry + (1 - a) * last.1
                }
                lastMeasSmooth = (rx, ry)
                if let kf = kalman {
                    framesSinceTrack += 1
                    kf.correct(x: rx, y: ry)
                    lastR = min(max(rr, 6), 90)
                    sx = kf.state[0]
                    sy = kf.state[1]
                } else {
                    let kf = BallKalman(x: rx, y: ry)
                    kalman = kf
                    framesSinceTrack = 0
                    lastR = rr
                    sx = kf.state[0]
                    sy = kf.state[1]
                }
                positions.append(Sample(x: sx!, y: sy!, frame: frameNumber, radius: lastR))
            } else if let kf = kalman, let pred = coastPred {
                noMeasStreak += 1
                let predFt = geometry.feet(atImage: CGPoint(x: pred.x, y: pred.y))
                let coastCap = predFt > 45.0 ? farCoastCap : maxPredOnlyFrames
                if noMeasStreak > coastCap {
                    if coastCap == farCoastCap {
                        // Lost deep down-lane: the shot is over. The coasted tail
                        // is prediction-only; drop it from the path and freeze so
                        // a later shot in the clip can't append onto this one.
                        if positions.count > farCoastCap {
                            positions.removeLast(farCoastCap)
                        }
                        trackFinished = true
                    }
                    kalman = nil
                    noMeasStreak = 0
                    lastMeasSmooth = nil
                    framesSinceTrack = 0
                } else {
                    kf.coast()
                    sx = pred.x
                    sy = pred.y
                    positions.append(Sample(x: pred.x, y: pred.y, frame: frameNumber, radius: lastR))
                }
            }

            if let sx, let sy {
                let contact = CGPoint(x: sx, y: sy + lastR)
                let ft = geometry.feet(atImage: contact)
                if dotCrossedFrame == nil, ft >= LaneGeometry.dotDistanceFeet {
                    dotCrossedFrame = frameNumber
                }
                // Stop at the pin deck (2% short of 60 ft, like the pixel margin).
                if ft >= LaneGeometry.laneLengthFeet * 0.98 {
                    trackFinished = true
                    kalman = nil
                    lastMeasSmooth = nil
                }
            }
        }

        return Self.postProcess(
            positions: positions, geometry: geometry, fps: fpsSafe,
            rawSize: naturalSize, orientation: orientation
        )
    }

    // MARK: - Post-processing (metrics from the tracked path)

    private static func postProcess(
        positions: [Sample], geometry: LaneGeometry, fps: Double,
        rawSize: CGSize, orientation: CGImagePropertyOrientation
    ) -> ShotResult {
        let displaySize: CGSize
        switch orientation {
        case .right, .left:
            displaySize = CGSize(width: rawSize.height, height: rawSize.width)
        default:
            displaySize = rawSize
        }
        var boards: [Double] = []
        var feet: [Double] = []
        var frames: [Double] = []
        for s in positions {
            let (b, f) = geometry.boardFeet(atImage: CGPoint(x: s.x, y: s.y + s.radius))
            boards.append(b)
            feet.append(f)
            frames.append(Double(s.frame))
        }

        var result = ShotResult(
            speedMph: nil, arrowBoard: nil, breakpointBoard: nil,
            breakpointFeet: nil, entryAngleDegrees: nil, path: [],
            videoPath: [], videoDisplaySize: displaySize,
            trackedFrames: positions.count
        )
        guard boards.count >= 3 else { return result }

        // Video-overlay trail: smoothed contact points (window 15, like the
        // prototype's display smoothing) mapped into display-normalized coords.
        let smoothX = savgolSmooth(positions.map(\.x), window: 15)
        let smoothY = savgolSmooth(positions.map(\.y), window: 15)
        result.videoPath = (0..<positions.count).map { i in
            let rx = smoothX[i] / Double(rawSize.width)
            let ry = (smoothY[i] + positions[i].radius) / Double(rawSize.height)
            let (u, v) = BallDetector.rawToOriented(rx: rx, ry: ry, orientation: orientation)
            return CGPoint(x: u, y: v)
        }

        // Lane-view path: smooth hard (window 41) and trim the last 2% (pin scatter).
        var pb = boards
        var pf = feet
        let trim = max(1, pb.count / 50)
        if pb.count > trim + 3 {
            pb.removeLast(trim)
            pf.removeLast(trim)
        }
        let sbPath = savgolSmooth(pb, window: 41)
        let sfPath = savgolSmooth(pf, window: 41)
        result.path = zip(sbPath, sfPath).map { (board: $0, feet: $1) }

        // Speed: regulation 6 ft between the foul line and dot row, timed from
        // interpolated crossings of the feet series (replaces the prototype's
        // clicked-line pixel tests).
        let sfAll = savgolSmooth(feet, window: 11)
        if let t0 = crossingFrame(feet: sfAll, frames: frames, target: 0.05, requireStartBelow: 0.5),
           let t6 = crossingFrame(feet: sfAll, frames: frames, target: LaneGeometry.dotDistanceFeet, requireStartBelow: 3.0),
           t6 > t0 {
            let seconds = (t6 - t0) / fps
            if seconds > 0 {
                result.speedMph = (LaneGeometry.dotDistanceFeet / seconds) * 0.681818
            }
        }

        // Arrow board: first crossing of the arrow V on the smoothed series,
        // linearly interpolated (port of arrow_board_from_path).
        let sbAll = savgolSmooth(boards, window: 11)
        var prevG = sfAll[0] - arrowFeet(atBoard: sbAll[0])
        for i in 1..<sbAll.count {
            let g = sfAll[i] - arrowFeet(atBoard: sbAll[i])
            if g >= 0 {
                let board: Double
                if prevG < 0, g != prevG {
                    let t = prevG / (prevG - g)
                    board = sbAll[i - 1] + t * (sbAll[i] - sbAll[i - 1])
                } else {
                    board = sbAll[i]
                }
                result.arrowBoard = (board * 10).rounded() / 10
                break
            }
            prevG = g
        }

        // Breakpoint: min board over the trimmed window (skip first third —
        // approach noise — and last 2%), on a smoothed series.
        if positions.count >= 10 {
            let n = boards.count
            let startIdx = n / 3
            let endIdx = max(startIdx + 1, n - max(1, n / 50))
            let wb = Array(boards[startIdx..<endIdx])
            let wf = Array(feet[startIdx..<endIdx])
            if wb.count >= 3 {
                let smooth = savgolSmooth(wb, window: 11)
                let minIdx = smooth.indices.min(by: { smooth[$0] < smooth[$1] })!
                result.breakpointBoard = (smooth[minIdx] * 10).rounded() / 10
                result.breakpointFeet = wf[minIdx]
                // Entry angle from the tail slope of the smoothed series.
                if smooth.count >= 5 {
                    let sfWin = savgolSmooth(wf, window: 11)
                    let tail = min(max(5, smooth.count / 6), smooth.count - 1)
                    let db = smooth[smooth.count - 1] - smooth[smooth.count - tail]
                    let df = sfWin[sfWin.count - 1] - sfWin[sfWin.count - tail]
                    if df > 0.5 {
                        let dbIn = db * (LaneGeometry.laneWidthInches / 39.0)
                        let dfIn = df * 12.0
                        let angle = atan2(dbIn, dfIn) * 180 / .pi
                        result.entryAngleDegrees = (angle * 10).rounded() / 10
                    }
                }
            } else if let minIdx = wb.indices.min(by: { wb[$0] < wb[$1] }) {
                result.breakpointBoard = (wb[minIdx] * 10).rounded() / 10
                result.breakpointFeet = wf[minIdx]
            }
        }

        return result
    }

    /// Interpolated frame index where the series first reaches `target` feet.
    /// Requires the series to start below `requireStartBelow` so a track that
    /// begins mid-lane doesn't produce an absurd speed.
    private static func crossingFrame(
        feet: [Double], frames: [Double], target: Double, requireStartBelow: Double
    ) -> Double? {
        guard let first = feet.first, first < requireStartBelow else { return nil }
        for i in 1..<feet.count where feet[i] >= target {
            let prev = feet[i - 1]
            if feet[i] == prev { return frames[i] }
            let t = (target - prev) / (feet[i] - prev)
            return frames[i - 1] + t * (frames[i] - frames[i - 1])
        }
        return nil
    }

    // MARK: - Measurement refinement

    /// Snap a measurement toward the ball's visual center using luma contrast
    /// inside the expected disk (port of refine_ball_center; the 420f luma plane
    /// is the grayscale image).
    private static func refineCenter(
        pixelBuffer: CVPixelBuffer, x: Double, y: Double, r: Double
    ) -> (Double, Double, Double) {
        let ri = min(max(r, 10), 92)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return (x, y, ri)
        }
        let w = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let h = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let luma = base.assumingMemoryBound(to: UInt8.self)

        let pad = 14.0
        let x1 = max(0, Int(x - ri - pad))
        let y1 = max(0, Int(y - ri - pad))
        let x2 = min(w, Int(x + ri + pad))
        let y2 = min(h, Int(y + ri + pad))
        guard x2 > x1 + 2, y2 > y1 + 2 else { return (x, y, ri) }

        let rw = x2 - x1
        let rh = y2 - y1
        // 5×5 Gaussian blur of the ROI (σ≈1.1, same taps as the lane detector).
        let k: [Double] = [0.0708, 0.2445, 0.3694, 0.2445, 0.0708]
        var tmp = [Double](repeating: 0, count: rw * rh)
        var blur = [Double](repeating: 0, count: rw * rh)
        for row in 0..<rh {
            for col in 0..<rw {
                var acc = 0.0
                for t in -2...2 {
                    let cc = min(max(col + t, 0), rw - 1)
                    acc += k[t + 2] * Double(luma[(y1 + row) * stride + x1 + cc])
                }
                tmp[row * rw + col] = acc
            }
        }
        for row in 0..<rh {
            for col in 0..<rw {
                var acc = 0.0
                for t in -2...2 {
                    let rr2 = min(max(row + t, 0), rh - 1)
                    acc += k[t + 2] * tmp[rr2 * rw + col]
                }
                blur[row * rw + col] = acc
            }
        }

        // Median inside the expected disk.
        let cx = x - Double(x1)
        let cy = y - Double(y1)
        var inDisk: [Double] = []
        inDisk.reserveCapacity(Int(ri * ri * 4))
        for row in 0..<rh {
            for col in 0..<rw {
                let dx = Double(col) - cx
                let dy = Double(row) - cy
                if dx * dx + dy * dy <= ri * ri {
                    inDisk.append(blur[row * rw + col])
                }
            }
        }
        guard inDisk.count >= 30 else { return (x, y, ri) }
        inDisk.sort()
        let med = inDisk[inDisk.count / 2]

        // Weighted centroid of |g − median| within the disk.
        var sum = 0.0
        var sumX = 0.0
        var sumY = 0.0
        for row in 0..<rh {
            for col in 0..<rw {
                let dx = Double(col) - cx
                let dy = Double(row) - cy
                guard dx * dx + dy * dy <= ri * ri else { continue }
                let wgt = abs(blur[row * rw + col] - med)
                sum += wgt
                sumX += Double(col) * wgt
                sumY += Double(row) * wgt
            }
        }
        guard sum > 1e-3 else { return (x, y, ri) }
        let rx = sumX / sum + Double(x1)
        let ry = sumY / sum + Double(y1)
        if hypot(rx - x, ry - y) > 42 { return (x, y, ri) }
        return (rx, ry, ri)
    }

    // MARK: - Orientation plumbing

    static func orientation(from transform: CGAffineTransform) -> CGImagePropertyOrientation {
        if transform.a == 0, transform.b == 1, transform.c == -1, transform.d == 0 {
            return .right
        }
        if transform.a == 0, transform.b == -1, transform.c == 1, transform.d == 0 {
            return .left
        }
        if transform.a == -1, transform.b == 0, transform.c == 0, transform.d == -1 {
            return .down
        }
        return .up
    }

    /// Corners were placed on the display-oriented frame; map them into the raw
    /// buffer's normalized space.
    static func cornersToRaw(_ corners: LaneCorners, orientation: CGImagePropertyOrientation) -> LaneCorners {
        func convert(_ p: CGPoint) -> CGPoint {
            let (rx, ry) = BallDetector.orientedToRaw(u: Double(p.x), v: Double(p.y), orientation: orientation)
            return CGPoint(x: rx, y: ry)
        }
        return LaneCorners(
            farLeft: convert(corners.farLeft),
            farRight: convert(corners.farRight),
            nearRight: convert(corners.nearRight),
            nearLeft: convert(corners.nearLeft)
        )
    }

    private static func dist2(_ c: BallDetector.Candidate, x: Double, y: Double) -> Double {
        let dx = c.x - x
        let dy = c.y - y
        return dx * dx + dy * dy
    }

    enum AnalyzerError: Error {
        case noVideoTrack
        case badCalibration
    }
}
