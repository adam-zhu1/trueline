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
    /// Board at 59.5 ft (Specto's entry board; 17.5 is flush pocket).
    var entryBoard: Double?
    /// Direction the ball leaves the hand, from the first tracked stretch.
    /// Positive = launched toward the gutter (a righty playing outside
    /// launches positive and hooks back at a positive entry angle).
    var launchAngleDegrees: Double? = nil
    /// Board where the launch stretch crosses the foul line (extrapolated
    /// back; only when the track starts in the first 8 ft).
    var foulLineBoard: Double? = nil
    /// Speed over the whole measured span, release area to the pins.
    var averageSpeedMph: Double? = nil
    /// Release to pins, seconds (tail projected to 59.5 ft).
    var shotTimeSeconds: Double? = nil
    /// Lateral acceleration through the hook phase, boards per second squared.
    var hookFactor: Double? = nil
    /// The hand the boards count from. Drawings mirror on it: a left-hander's
    /// boards run from the left gutter.
    var hand: LaneModel.Hand = .right
    /// Smoothed (board, feet) samples for drawing the lane-view path.
    var path: [(board: Double, feet: Double)]
    /// Smoothed ball-contact points in display-oriented normalized coordinates,
    /// for drawing the trail over the source video.
    var videoPath: [CGPoint]
    /// Video dimensions as displayed (orientation applied).
    var videoDisplaySize: CGSize
    var trackedFrames: Int
    /// Where the tracked throw sits in the source clip (seconds) — drives the
    /// replay trim on save. Nil when nothing was tracked.
    var throwStartSeconds: Double? = nil
    var throwEndSeconds: Double? = nil
    /// Set when the track isn't reliable: what went wrong, for the failure
    /// screen.
    var failure: TrackingFailure? = nil
    /// Per-sample track and gate counts, for the accuracy benchmark
    /// (experiments/accuracy_bench). Not shown in the app.
    var trace: AnalysisTrace? = nil

    /// A usable track: enough samples to draw a path and trust the metrics.
    var isReliable: Bool {
        trackedFrames >= 10 && path.count >= 2
    }
}

/// Offline analysis of a recorded throw — port of track_ball in
/// src/ball_tracking.py, YOLO branch only (Core ML replaces MOG2+Hough), with
/// all crossing logic in homography feet instead of pixel rows so it works for
/// any camera angle.
struct ShotAnalyzer {
    /// Stamped on every saved shot. 1 = TrueLine 1.0, whose contact point was
    /// computed in raw buffer axes and skewed boards sideways on portrait
    /// clips. 2 = interim 1.1 builds (developer phone only): contact point
    /// fix, wall-clock tracking, one lane model, but metrics still read off
    /// the Kalman state. 3 = metrics from the detector boxes, least-squares
    /// launch speed and the entry fit (6c22df7).
    /// Bump when a change moves the numbers a saved shot would show.
    static let version = 3

    var detector: BallDetector
    var corners: LaneCorners
    var hand: LaneGeometry.Hand

    /// Ball radius (raw px) below which the focus crop is used.
    static let focusMaxRadiusPx = 22.0

    private struct Sample {
        var x: Double
        var y: Double
        var frame: Int
        var radius: Double
        /// The detector box behind a measured sample (nil while coasting).
        var detection: BallDetector.Candidate? = nil
        /// That detection after refineCenter, before any smoothing.
        var refined: CGPoint? = nil
    }

    /// `livePath` receives the tracked path so far (display-normalized, like
    /// ShotResult.videoPath but unsmoothed) at the same cadence as `progress`.
    /// It is a snapshot, not a delta: the tracker drops coasted tails and
    /// false locks retroactively, so the path can shrink between calls.
    func analyze(
        videoURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil,
        livePath: (@Sendable ([CGPoint]) -> Void)? = nil
    ) async throws -> ShotResult {
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
        // Every frame-count heuristic below was tuned on 30 fps footage; fpsScale
        // converts them to the same wall-clock span at any capture rate.
        let fpsScale = fpsSafe / 30.0
        let maxPredOnlyFrames = Int((75 * fpsScale).rounded())
        // Past 45 ft a coasting prediction paints a straight line exactly where
        // the hook matters; a short cap there corrupts far less path.
        let farCoastCap = Int((12 * fpsScale).rounded())
        let tentativeCoastCap = Int((10 * fpsScale).rounded())
        var maxJumpPx = geometry.pixelsPerFoot * 72.0 / fpsSafe
        maxJumpPx = min(max(maxJumpPx, 32), 320)
        var lastMeasSmooth: (Double, Double)?
        var framesSinceTrack = 0
        var trackFinished = false
        var dotCrossedFrame: Int?
        var frameNumber = 0
        let laneCentroid = geometry.laneCentroid

        // Always on: the gate counts are cheap, and a failed throw's screen
        // explains itself from them. Only the console dump is debug-only.
        let diag: DetectorDiagnostics? = DetectorDiagnostics()
        var measuredFrames = 0
        var coastedFrames = 0
        var assocRejects = 0
        var lastMeasuredFeet = 0.0
        var trackStartFeet = 0.0
        var trackMeasured = 0
        var kalmanResets = 0
        var focusHits = 0
        // positions index where the current lock began.
        var trackStartIndex = 0
        // Contiguous runs of real measurements (frame + feet), for the debug log.
        var measSegments: [(f0: Int, f1: Int, ft0: Double, ft1: Double)] = []

        while let sampleBuffer = autoreleasepool(invoking: { output.copyNextSampleBuffer() }) {
            // A cancelled analysis (user backed out) must stop decoding, not
            // grind through the rest of the clip.
            try Task.checkCancellation()
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            // The rest of the clip is the bowler walking back to the phone —
            // decoding it buys nothing once the track is frozen.
            if trackFinished { break }
            frameNumber += 1
            if frameNumber % 10 == 0 {
                progress?(min(Double(frameNumber) / Double(totalFrames), 1.0))
                livePath?(positions.map {
                    Self.displayPoint($0, rawSize: naturalSize, orientation: orientation)
                })
            }

            // Predict before detecting: when the full frame finds nothing, a
            // confirmed track's prediction aims a second, native-resolution
            // pass (the focus crop) at where the ball should be. Full frame
            // stays first: its boxes are what the metrics were validated on,
            // and the crop only fills the gaps where the downscaled frame
            // loses a small far-lane ball.
            let pred = kalman?.predict()
            var candidates = detector.candidates(
                in: pixelBuffer, orientation: orientation, geometry: geometry, diag: diag
            )
            if candidates.isEmpty, let pred, trackMeasured >= 3, lastR <= Self.focusMaxRadiusPx {
                candidates = detector.candidates(
                    in: pixelBuffer, orientation: orientation, geometry: geometry,
                    focus: CGPoint(x: pred.x, y: pred.y), diag: diag
                )
                if !candidates.isEmpty { focusHits += 1 }
            }

            var measurement: BallDetector.Candidate?
            var coastPred: (x: Double, y: Double)?

            if let kf = kalman, let pred {
                coastPred = pred
                if let nearest = candidates.min(by: {
                    Self.dist2($0, x: pred.x, y: pred.y) < Self.dist2($1, x: pred.x, y: pred.y)
                }) {
                    let d = Self.dist2(nearest, x: pred.x, y: pred.y).squareRoot()
                    // Widen gate early (release noise) and later (hook lag).
                    let jumpScale: Double
                    if Double(frameNumber) <= 140 * fpsScale {
                        jumpScale = 1.55
                    } else if let dc = dotCrossedFrame, frameNumber >= dc {
                        jumpScale = 1.48
                    } else {
                        jumpScale = 1.32
                    }
                    let scale = geometry.laneWidthScale(atImage: CGPoint(x: pred.x, y: pred.y))
                    // Coasting compounds prediction error; the gate must grow
                    // with the blind streak or the ball can't re-attach after a
                    // detection gap.
                    let coastGrow = 1.0 + min(Double(noMeasStreak) / fpsScale * 0.04, 1.5)
                    let jumpOK = max(28.0, maxJumpPx * jumpScale * scale * coastGrow)
                    if d <= jumpOK { measurement = nearest } else { assocRejects += 1 }
                }
            } else if !candidates.isEmpty {
                // First lock: largest ball-sized candidate nearest the lane center.
                // Locking needs strong evidence — the detector's graded threshold
                // admits sub-MAIN_CONF boxes mid-lane, but those may only continue
                // a track, never start one (a weak pre-throw box would false-lock).
                let strong = candidates.filter { $0.confidence >= BallDetector.mainConf }
                let ballish = strong.filter { $0.radius >= 10 && $0.radius <= 58 }
                let pool = ballish.isEmpty ? strong : ballish
                let cx = Double(laneCentroid.x)
                let cy = Double(laneCentroid.y)
                measurement = pool.min(by: {
                    Self.dist2($0, x: cx, y: cy) < Self.dist2($1, x: cx, y: cy)
                })
            }

            var sx: Double?
            var sy: Double?

            if let m = measurement {
                measuredFrames += 1
                let gapFrames = noMeasStreak
                noMeasStreak = 0
                var (rx, ry, rr) = Self.refineCenter(
                    pixelBuffer: pixelBuffer, x: m.x, y: m.y, r: m.radius
                )
                let refined = CGPoint(x: rx, y: ry)
                if let last = lastMeasSmooth, gapFrames == 0, framesSinceTrack > Int((7 * fpsScale).rounded()) {
                    let a = 1 - pow(1 - 0.42, 1 / fpsScale)
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
                    trackStartIndex = positions.count
                    framesSinceTrack = 0
                    lastR = rr
                    sx = kf.state[0]
                    sy = kf.state[1]
                }
                positions.append(Sample(x: sx!, y: sy!, frame: frameNumber, radius: lastR, detection: m, refined: refined))
                lastMeasuredFeet = geometry.feet(
                    atImage: Self.contactRaw(x: sx!, y: sy!, radius: lastR, orientation: orientation)
                )
                trackMeasured += 1
                if trackMeasured == 1 { trackStartFeet = lastMeasuredFeet }
                if var seg = measSegments.last, Double(frameNumber - seg.f1) <= 15 * fpsScale {
                    seg.f1 = frameNumber
                    seg.ft1 = lastMeasuredFeet
                    measSegments[measSegments.count - 1] = seg
                } else {
                    measSegments.append((frameNumber, frameNumber, lastMeasuredFeet, lastMeasuredFeet))
                }
            } else if let kf = kalman, let pred = coastPred {
                noMeasStreak += 1
                let predFt = geometry.feet(atImage: CGPoint(x: pred.x, y: pred.y))
                // An unconfirmed lock (a stray box before the throw) carries no velocity;
                // letting it coast for seconds blocks the real ball from locking.
                let coastCap = trackMeasured < 3
                    ? tentativeCoastCap
                    : (predFt > 45.0 ? farCoastCap : maxPredOnlyFrames)
                if noMeasStreak > coastCap {
                    // However the track ends, the coasted tail is prediction-only,
                    // not data — drop the whole blind streak from the path (it can
                    // exceed coastCap when the cap switches near→far mid-streak).
                    positions.removeLast(min(noMeasStreak - 1, positions.count))
                    if coastCap == farCoastCap {
                        // Lost deep down-lane: the shot is over. Freeze so a later
                        // shot in the clip can't append onto this one.
                        trackFinished = true
                    } else if trackMeasured >= 10, lastMeasuredFeet - trackStartFeet >= 15 {
                        // A real throw was tracked and then lost for a long blind
                        // streak: the ball is gone. Freezing (instead of resetting
                        // for a new lock) stops a looped/replayed clip from
                        // painting a second pass over this track.
                        trackFinished = true
                    } else {
                        // Not a throw (a stray lock that never moved): its
                        // samples aren't part of any path.
                        kalmanResets += 1
                        positions.removeLast(max(0, positions.count - trackStartIndex))
                    }
                    kalman = nil
                    noMeasStreak = 0
                    lastMeasSmooth = nil
                    framesSinceTrack = 0
                    trackMeasured = 0
                } else {
                    kf.coast()
                    coastedFrames += 1
                    sx = pred.x
                    sy = pred.y
                    positions.append(Sample(x: pred.x, y: pred.y, frame: frameNumber, radius: lastR))
                }
            }

            if let sx, let sy {
                let contact = Self.contactRaw(x: sx, y: sy, radius: lastR, orientation: orientation)
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

        if reader.status == .reading { reader.cancelReading() }

        #if DEBUG
        print("focus crop: hits on \(focusHits) frames")
        if let diag {
            Self.logDiagnostics(
                diag: diag, geometry: geometry, rawSize: naturalSize,
                orientation: orientation, fps: fpsSafe, maxJumpPx: maxJumpPx,
                measured: measuredFrames, coasted: coastedFrames,
                assocRejects: assocRejects, tracked: positions.count,
                lastMeasuredFeet: lastMeasuredFeet,
                kalmanResets: kalmanResets, measSegments: measSegments
            )
        }
        #endif

        var result = Self.postProcess(
            positions: positions, geometry: geometry, fps: fpsSafe,
            rawSize: naturalSize, orientation: orientation
        )
        if !result.isReliable, let diag {
            result.failure = TrackingFailure.classify(
                rawBoxes: diag.rawBoxes, outsideLane: diag.outsideLane, accepted: diag.accepted
            )
        }
        result.hand = hand
        result.trace = AnalysisTrace(
            fps: fpsSafe,
            orientation: orientation.rawValue,
            samples: positions.map { s in
                let contact = Self.contactRaw(x: s.x, y: s.y, radius: s.radius, orientation: orientation)
                let (b, f) = geometry.boardFeet(atImage: contact)
                return AnalysisTrace.Sample(
                    frame: s.frame, x: s.x, y: s.y, radius: s.radius, board: b, feet: f,
                    detectionX: s.detection?.x, detectionY: s.detection?.y,
                    detectionRadius: s.detection?.radius, confidence: s.detection?.confidence,
                    refinedX: s.refined.map { Double($0.x) }, refinedY: s.refined.map { Double($0.y) }
                )
            },
            framesDecoded: diag?.frames ?? 0, rawBoxes: diag?.rawBoxes ?? 0,
            belowFloor: diag?.belowFloor ?? 0, outsideLane: diag?.outsideLane ?? 0,
            lowConfNear: diag?.lowConfNear ?? 0, accepted: diag?.accepted ?? 0,
            measured: measuredFrames, coasted: coastedFrames,
            associationRejects: assocRejects, trackResets: kalmanResets, focusHits: focusHits
        )
        return result
    }

    #if DEBUG
    /// One console block per analysis: where candidates died on the way to the
    /// tracker. Reading it: zero raw boxes → the model can't see the ball in
    /// this footage; raw boxes mostly dying at "outside lane" → the calibrated
    /// quad doesn't cover the ball's path (check the reject samples against the
    /// quad corners); accepted candidates but few tracked frames → the
    /// association gate is dropping the lock.
    private static func logDiagnostics(
        diag: DetectorDiagnostics, geometry: LaneGeometry, rawSize: CGSize,
        orientation: CGImagePropertyOrientation, fps: Double, maxJumpPx: Double,
        measured: Int, coasted: Int, assocRejects: Int, tracked: Int,
        lastMeasuredFeet: Double,
        kalmanResets: Int, measSegments: [(f0: Int, f1: Int, ft0: Double, ft1: Double)]
    ) {
        let orient: String
        switch orientation {
        case .up: orient = "up"
        case .down: orient = "down"
        case .left: orient = "left"
        case .right: orient = "right"
        default: orient = "other(\(orientation.rawValue))"
        }
        let quad = geometry.quad
            .map { String(format: "(%.0f,%.0f)", $0.x, $0.y) }
            .joined(separator: " ")
        var lines = [
            "═══ TrueLine analysis diagnostics ═══",
            String(
                format: "video: %.0f×%.0f raw, orientation %@, %.1f fps, %d frames decoded",
                rawSize.width, rawSize.height, orient, fps, diag.frames
            ),
            String(
                format: "quad (raw px, foulR foulL pinL pinR): %@ | px/ft %.1f | jump gate %.0f px",
                quad, geometry.pixelsPerFoot, maxJumpPx
            ),
            "detector: \(diag.rawBoxes) raw boxes on \(diag.framesWithRaw)/\(diag.frames) frames"
                + " → rejected \(diag.belowFloor) below conf \(BallDetector.farConf),"
                + " \(diag.outsideLane) outside lane quad,"
                + " \(diag.lowConfNear) low-conf before \(Int(BallDetector.farFeet)) ft"
                + " → \(diag.accepted) accepted",
            "tracker: \(measured) measured + \(coasted) coasted = \(tracked) tracked frames"
                + " (need ≥ 10); \(assocRejects) candidates rejected by the jump gate"
                + String(format: "; last real detection at %.1f ft", lastMeasuredFeet)
                + (kalmanResets > 0 ? "; \(kalmanResets) track resets" : ""),
        ]
        let buckets = diag.acceptedBuckets.enumerated().compactMap { i, b -> String? in
            guard b.n > 0 else { return nil }
            let label = i < 4 ? "\(i * 10)–\((i + 1) * 10)ft" : "40ft+"
            return String(format: "%@ %.2f×%d", label, b.sum / Double(b.n), b.n)
        }
        if !buckets.isEmpty {
            lines.append("  accepted conf by distance: " + buckets.joined(separator: "  "))
        }
        if !measSegments.isEmpty {
            let segs = measSegments
                .map { String(format: "f%d–%d (%.1f→%.1f ft)", $0.f0, $0.f1, $0.ft0, $0.ft1) }
                .joined(separator: "  ")
            lines.append("  measured segments: \(segs)")
        }
        if !diag.lowConfSamples.isEmpty {
            let s = diag.lowConfSamples
                .map { String(format: "%.0fft/%.2f", $0.feet, $0.confidence) }
                .joined(separator: " ")
            lines.append("  low-conf rejects (feet/conf): \(s)")
        }
        if diag.performErrors > 0 {
            lines.append("vision: request THREW on \(diag.performErrors)/\(diag.frames) frames"
                + " — first: \(diag.firstPerformError ?? "?")")
        }
        if diag.castFailures > 0 {
            lines.append("vision: results were not object observations on"
                + " \(diag.castFailures) frames — saw: \(diag.castFailureTypes ?? "?")")
        }
        for s in diag.laneRejectSamples {
            lines.append(String(
                format: "  lane reject: (%.0f, %.0f) conf %.2f, %.0f px outside",
                s.x, s.y, s.confidence, -s.distance
            ))
        }
        if diag.performErrors == diag.frames, diag.frames > 0 {
            lines.append("verdict: every Vision request failed — see the error above")
        } else if diag.castFailures > 0, diag.rawBoxes == 0 {
            lines.append("verdict: the model is returning the wrong observation type — likely an export/pipeline issue")
        } else if diag.rawBoxes == 0 {
            lines.append("verdict: the model returned nothing on any frame — this footage is below what the detector can see")
        } else if diag.outsideLane > diag.accepted {
            lines.append("verdict: the lane gate is the dominant filter — compare the reject samples against the quad corners above")
        } else if diag.accepted > 0, tracked < 10 {
            lines.append("verdict: detections exist but no stable lock — look at the jump-gate rejects and whether accepted boxes are scattered")
        }
        lines.append("═════════════════════════════════════")
        print(lines.joined(separator: "\n"))
    }
    #endif

    /// One tracked sample's contact point in display-normalized coordinates —
    /// the live-progress version of the videoPath mapping in postProcess.
    private static func displayPoint(
        _ s: Sample, rawSize: CGSize, orientation: CGImagePropertyOrientation
    ) -> CGPoint {
        let contact = contactRaw(x: s.x, y: s.y, radius: s.radius, orientation: orientation)
        let rx = Double(contact.x) / Double(rawSize.width)
        let ry = Double(contact.y) / Double(rawSize.height)
        let (u, v) = BallDetector.rawToOriented(rx: rx, ry: ry, orientation: orientation)
        return CGPoint(x: u, y: v)
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
        // Metrics come from the detector's own boxes on measured frames, not
        // from the tracker state. The Kalman filter (fed through refineCenter
        // and an exponential smoother) is what keeps the lock, but its state
        // lags the ball: 10+ px at release, 2-3 px at the pins. Against
        // hand-labelled frames (experiments/accuracy_bench) the raw box
        // centre is the most accurate position the pipeline has (median
        // 1.2 px at the pins vs 2.6 refined and 2.9 Kalman), and coasted
        // frames are predictions, not data: a track that coasts into the
        // pin deck painted a straight line exactly where entry is read.
        let measured = metricSamples(positions)
        var boards: [Double] = []
        var feet: [Double] = []
        var frames: [Double] = []
        for s in measured {
            let contact = contactRaw(x: s.x, y: s.y, radius: s.radius, orientation: orientation)
            let (b, f) = geometry.boardFeet(atImage: contact)
            boards.append(b)
            feet.append(f)
            frames.append(Double(s.frame))
        }

        var result = ShotResult(
            speedMph: nil, arrowBoard: nil, breakpointBoard: nil,
            breakpointFeet: nil, entryAngleDegrees: nil, entryBoard: nil,
            path: [], videoPath: [], videoDisplaySize: displaySize,
            trackedFrames: positions.count
        )
        if let first = positions.first, let last = positions.last {
            result.throwStartSeconds = Double(first.frame - 1) / fps
            result.throwEndSeconds = Double(last.frame) / fps
        }
        guard positions.count >= 3 else { return result }
        // Smoothing windows are counted in samples and were tuned at 30 fps;
        // keep the same time span at other rates (odd, as Savitzky–Golay needs).
        func win(_ samplesAt30: Int) -> Int {
            let n = Int((Double(samplesAt30) * fps / 30).rounded())
            return n % 2 == 0 ? n + 1 : n
        }

        // Video-overlay trail: smoothed contact points (window 15, like the
        // prototype's display smoothing) mapped into display-normalized coords.
        let smoothX = savgolSmooth(positions.map(\.x), window: win(15))
        let smoothY = savgolSmooth(positions.map(\.y), window: win(15))
        result.videoPath = (0..<positions.count).map { i in
            let contact = contactRaw(
                x: smoothX[i], y: smoothY[i], radius: positions[i].radius, orientation: orientation
            )
            let rx = Double(contact.x) / Double(rawSize.width)
            let ry = Double(contact.y) / Double(rawSize.height)
            let (u, v) = BallDetector.rawToOriented(rx: rx, ry: ry, orientation: orientation)
            return CGPoint(x: u, y: v)
        }
        guard boards.count >= 3 else { return result }

        // Lane-view path: smooth hard (window 41) and trim the last 2% (pin scatter).
        var pb = boards
        var pf = feet
        let trim = max(1, pb.count / 50)
        if pb.count > trim + 3 {
            pb.removeLast(trim)
            pf.removeLast(trim)
        }
        let sbPath = savgolSmooth(pb, window: win(41))
        let sfPath = savgolSmooth(pf, window: win(41))
        result.path = zip(sbPath, sfPath).map { (board: $0, feet: $1) }

        // Launch speed: least-squares slope of feet against time over the
        // first 16 ft of measured track (see launchSpeedMph).
        let settleSkip = min(Int((3 * fps / 30).rounded()), feet.count - 1)
        let f0 = max(feet[settleSkip], 0.05)
        result.speedMph = Self.launchSpeedMph(
            feet: Array(feet[settleSkip...]), frames: Array(frames[settleSkip...]), fps: fps
        )

        // Average speed and shot time over release-to-pins, the measurement
        // capped at 59.5 ft (tracks run past the deck into pin scatter) and a
        // short track's remainder projected at its tail velocity. Long-baseline
        // numbers only: the far lane is too few pixels at 1x for an honest
        // last-6-ft impact speed (measured ±5 mph segment noise past 50 ft),
        // so impact speed and speed loss wait for 2x footage.
        if feet[settleSkip] <= 8.0, let lastFeet = feet.last, let lastFrame = frames.last, lastFeet >= 50,
           let t0 = crossingFrame(feet: feet, frames: frames, target: f0, requireStartBelow: f0 + 0.5) {
            let endFeet = min(lastFeet, LaneGeometry.entryBoardFeet)
            if let tTail = crossingFrame(feet: feet, frames: frames, target: endFeet - 6.0, requireStartBelow: f0 + 0.5),
               let tEnd = lastFeet >= LaneGeometry.entryBoardFeet
                   ? crossingFrame(feet: feet, frames: frames, target: LaneGeometry.entryBoardFeet, requireStartBelow: f0 + 0.5)
                   : lastFrame,
               tEnd > tTail {
                let tailFtPerSec = 6.0 / ((tEnd - tTail) / fps)
                let secondsToPins = (tEnd - t0) / fps + max(0, LaneGeometry.entryBoardFeet - endFeet) / tailFtPerSec
                if secondsToPins > 0 {
                    result.shotTimeSeconds = (secondsToPins * 100).rounded() / 100
                    result.averageSpeedMph = ((LaneGeometry.entryBoardFeet - f0) / secondsToPins) * 0.681818
                }
            }
        }

        // Arrow board: first crossing of the arrow V on the smoothed series,
        // linearly interpolated (port of arrow_board_from_path).
        let sbAll = savgolSmooth(boards, window: win(11))
        let sfAll = savgolSmooth(feet, window: win(11))
        var prevG = sfAll[0] - LaneModel.arrowFeet(atBoardPosition: sbAll[0])
        for i in 1..<sbAll.count {
            let g = sfAll[i] - LaneModel.arrowFeet(atBoardPosition: sbAll[i])
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

        // Launch angle: slope of the first tracked stretch on the smoothed
        // series. Same geometry as entry angle, opposite end and sign — and
        // like speed it must start in the front of the lane (a mid-lane lock
        // isn't a launch).
        let skipHead = min(3, sbAll.count - 1)
        if feet[skipHead] <= 15.0 {
            let head = min(max(5, sbAll.count / 6), sbAll.count - 1 - skipHead)
            if head >= 2 {
                let db = sbAll[skipHead + head] - sbAll[skipHead]
                let df = sfAll[skipHead + head] - sfAll[skipHead]
                if df > 0.5 {
                    let dbIn = db * LaneModel.inchesPerBoard
                    let angle = -atan2(dbIn, df * 12.0) * 180 / .pi
                    result.launchAngleDegrees = (angle * 10).rounded() / 10
                    // Foul-line board: the same launch slope walked back to
                    // 0 ft. Short walk only — a track that starts deep would
                    // extrapolate a guess, not a measurement.
                    if feet[skipHead] <= 8.0 {
                        let projected = sbAll[skipHead] - (db / df) * sfAll[skipHead]
                        if projected >= 0, projected <= 39 {
                            result.foulLineBoard = (projected * 10).rounded() / 10
                        }
                    }
                }
            }
        }

        // Breakpoint: min board over the trimmed window (skip first third —
        // approach noise — and last 2%), on a smoothed series.
        if boards.count >= 10 {
            let n = boards.count
            let startIdx = n / 3
            let endIdx = max(startIdx + 1, n - max(1, n / 50))
            let wb = Array(boards[startIdx..<endIdx])
            let wf = Array(feet[startIdx..<endIdx])
            if wb.count >= 3 {
                let smooth = savgolSmooth(wb, window: win(11))
                let minIdx = smooth.indices.min(by: { smooth[$0] < smooth[$1] })!
                result.breakpointBoard = (smooth[minIdx] * 10).rounded() / 10
                result.breakpointFeet = wf[minIdx]
                // Hook factor: lateral acceleration through the hook — board
                // velocity over the tail minus board velocity approaching the
                // breakpoint, per second between the two windows.
                let wframes = Array(frames[startIdx..<endIdx])
                let k = max(5, smooth.count / 6)
                if minIdx >= k, smooth.count - minIdx > k,
                   let pre = linearSlope(
                       Array(smooth[(minIdx - k)...minIdx]),
                       wframes[(minIdx - k)...minIdx].map { $0 / fps }
                   ),
                   let post = linearSlope(
                       Array(smooth.suffix(k)),
                       wframes.suffix(k).map { $0 / fps }
                   ) {
                    let dt = (wframes[wframes.count - 1 - k / 2] - wframes[minIdx - k / 2]) / fps
                    if dt > 0.1 {
                        result.hookFactor = (((post - pre) / dt) * 10).rounded() / 10
                    }
                }
            } else if let minIdx = wb.indices.min(by: { wb[$0] < wb[$1] }) {
                result.breakpointBoard = (wb[minIdx] * 10).rounded() / 10
                result.breakpointFeet = wf[minIdx]
            }
        }

        // Entry board and angle: one fit through the measured back end,
        // read at 59.5 ft (see entryFit).
        if boards.count >= 10, let entry = Self.entryFit(boards: boards, feet: feet) {
            result.entryBoard = (min(max(entry.board, 0), 39) * 10).rounded() / 10
            result.entryAngleDegrees = (entry.angleDegrees * 10).rounded() / 10
        }

        return result
    }

    /// The samples metrics are computed from: measured frames only, each at
    /// its detector box (centre and radius), in track order. Falls back to
    /// the tracked positions when fewer than three frames were measured.
    private static func metricSamples(_ positions: [Sample]) -> [Sample] {
        let measured = positions.compactMap { s in
            s.detection.map { Sample(x: $0.x, y: $0.y, frame: s.frame, radius: $0.radius) }
        }
        return measured.count >= 3 ? measured : positions
    }

    /// Launch speed, mph: least-squares slope of feet against time over the
    /// first 16 ft of track. It must start in the front of the lane
    /// (<= 15 ft): the ball sheds 2-3 mph down-lane, so a mid-lane reading
    /// isn't a launch speed. The old two-crossing 6 ft window on the Kalman
    /// state read 12.8 to 20.6 mph on throws whose hand labels say 15.1 to
    /// 15.9: a filter that starts at zero velocity lags hardest exactly
    /// where launch speed is timed, and two crossings of a noisy series
    /// carry each one's timing error straight into the speed. A fit over
    /// every sample in 16 ft averages it down (0.2 mph mean error against
    /// labels, and the 30 and 60 fps copies of one throw agree to 0.2 mph).
    /// `feet`/`frames`: the measured series with the release frames already
    /// skipped.
    static func launchSpeedMph(feet: [Double], frames: [Double], fps: Double) -> Double? {
        guard feet.count == frames.count, let start = feet.first, start <= 15.0, fps > 0 else { return nil }
        var t: [Double] = []
        var f: [Double] = []
        for i in feet.indices where feet[i] <= start + launchSpanFeet {
            t.append(frames[i] / fps)
            f.append(feet[i])
        }
        guard t.count >= 5, let lo = f.min(), let hi = f.max(), hi - lo >= 6.0,
              let slope = linearSlope(f, t), slope > 0 else { return nil }
        return slope * 0.681818
    }

    static let launchSpanFeet = 16.0

    /// Entry board (at 59.5 ft) and entry angle (degrees, positive = moving
    /// toward higher boards) from the measured back end.
    ///
    /// Window: samples from 40 ft to 59.5 ft, cut where the ball deflects
    /// (pin contact turns it back across boards; IMG_5113's tracker followed
    /// it 4 boards back toward the gutter and read entry 11.2 on a throw the
    /// labels put at 19.3). Fit: quadratic in feet when the window has 8+
    /// samples over 10+ ft, else a line; board and slope are read at
    /// 59.5 ft. The ball is still hooking at 40-55 ft, so the old tail
    /// slope over the last sixth of a lagged, smoothed track read the angle
    /// low and, projected from the track's last point, the board high
    /// (+0.8 to +1.2 boards on every batch-1 clip).
    static func entryFit(boards: [Double], feet: [Double]) -> (board: Double, angleDegrees: Double)? {
        var b: [Double] = []
        var f: [Double] = []
        for i in boards.indices where feet[i] >= 40.0 && feet[i] <= LaneGeometry.entryBoardFeet {
            b.append(boards[i])
            f.append(feet[i])
        }
        guard b.count >= 5 else { return nil }
        let cut = deflectionCut(b)
        b = Array(b[..<cut])
        f = Array(f[..<cut])
        guard b.count >= 5, let last = f.last, let first = f.first,
              last >= 50, last - first >= 5 else { return nil }
        let x = f.map { $0 - LaneGeometry.entryBoardFeet }
        let line = polyfit(x: x, y: b, degree: 1)
        var coeffs = line
        if b.count >= 8, last - first >= 10, let quad = polyfit(x: x, y: b, degree: 2) {
            // A quadratic extrapolated past a short or noisy tail can bend
            // away; keep it only while it stays near the line.
            if let line, abs(quad[0] - line[0]) <= 3, abs(quad[1]) <= 3 {
                coeffs = quad
            }
        }
        guard let c = coeffs else { return nil }
        let angle = atan(c[1] * LaneModel.inchesPerBoard / 12.0) * 180 / .pi
        return (c[0], angle)
    }

    /// Index one past the last sample to keep: the ball's sideways run
    /// toward the pocket ends at the deflection. Hook direction is the
    /// window's first-to-last trend; the cut lands on the extreme sample
    /// once two samples in a row fall more than 0.6 board back from it
    /// (single-frame detector noise is under half a board at the pins).
    static func deflectionCut(_ b: [Double]) -> Int {
        guard let first = b.first, let last = b.last else { return 0 }
        let sign: Double = last >= first ? 1 : -1
        var best = -Double.infinity
        var bestIdx = 0
        var below = 0
        for (i, v) in b.enumerated() {
            let s = v * sign
            if s > best {
                best = s
                bestIdx = i
                below = 0
            } else if best - s > 0.6 {
                below += 1
                if below >= 2 { return bestIdx + 1 }
            }
        }
        return b.count
    }

    /// Least-squares polynomial (degree 1 or 2) of y on x; coefficients
    /// lowest order first: c[0] + c[1] x + c[2] x². nil when singular.
    static func polyfit(x: [Double], y: [Double], degree: Int) -> [Double]? {
        let terms = degree + 1
        guard x.count == y.count, x.count >= terms else { return nil }
        var a = [[Double]](repeating: [Double](repeating: 0, count: terms + 1), count: terms)
        for i in x.indices {
            var powers = [Double](repeating: 1, count: 2 * terms - 1)
            for k in 1..<powers.count { powers[k] = powers[k - 1] * x[i] }
            for r in 0..<terms {
                for c in 0..<terms { a[r][c] += powers[r + c] }
                a[r][terms] += powers[r] * y[i]
            }
        }
        return Homography.gaussianSolve(&a, n: terms)
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

    /// Least-squares slope of y against t; nil when t has no spread.
    private static func linearSlope(_ y: [Double], _ t: [Double]) -> Double? {
        guard y.count == t.count, y.count >= 2 else { return nil }
        let n = Double(y.count)
        let mt = t.reduce(0, +) / n
        let my = y.reduce(0, +) / n
        var num = 0.0
        var den = 0.0
        for i in 0..<y.count {
            num += (t[i] - mt) * (y[i] - my)
            den += (t[i] - mt) * (t[i] - mt)
        }
        guard den > 1e-9 else { return nil }
        return num / den
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

    /// Ball contact point (bottom of the ball as displayed) in raw buffer
    /// coords. Display-down is a different raw axis per orientation — adding
    /// the radius to raw y on a rotated buffer shifts the point ACROSS the
    /// lane instead of down it, which read pocket hits as Brooklyn (one ball
    /// radius of sideways error, ~7 boards at the deck).
    static func contactRaw(
        x: Double, y: Double, radius: Double, orientation: CGImagePropertyOrientation
    ) -> CGPoint {
        switch orientation {
        case .right: return CGPoint(x: x + radius, y: y)
        case .left: return CGPoint(x: x - radius, y: y)
        case .down: return CGPoint(x: x, y: y - radius)
        default: return CGPoint(x: x, y: y + radius)
        }
    }

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
