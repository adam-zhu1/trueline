import CoreGraphics
import CoreML
import Vision

/// Core ML ball detector — port of src/yolo_ball.py's BallDetector. One forward
/// pass per frame; boxes convert to (center, radius) candidates, gated to the
/// lane polygon. NMS is baked into the exported model, so Vision hands back
/// ready-made object observations.
final class BallDetector {
    /// Past this distance the ball is small/blurred and legitimately scores
    /// lower; detections there only need FAR_CONF instead of the main threshold.
    static let farFeet = 40.0
    static let farConf = 0.18
    static let mainConf = 0.35

    struct Candidate {
        var x: Double
        var y: Double
        var radius: Double
        var confidence: Double
    }

    private let vnModel: VNCoreMLModel

    init(model: MLModel) throws {
        vnModel = try VNCoreMLModel(for: model)
        // The exported pipeline bakes in confidenceThreshold 0.25, which would
        // silently defeat the FAR_CONF floor below; feed it our thresholds.
        vnModel.featureProvider = ThresholdProvider()
    }

    /// Candidates in raw-buffer pixel coordinates. `orientation` tells Vision how
    /// the buffer maps to display-upright so the model sees what it trained on;
    /// returned boxes are converted back to raw coordinates for the tracker.
    func candidates(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        geometry: LaneGeometry,
        diag: DetectorDiagnostics? = nil
    ) -> [Candidate] {
        let request = VNCoreMLRequest(model: vnModel)
        // Letterbox like Ultralytics training/inference; stretching the frame
        // square (scaleFill) squashes the ball on portrait clips and costs
        // detections. Vision maps the boxes back to original-image normalized
        // coordinates either way.
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        diag?.frames += 1
        do {
            try handler.perform([request])
        } catch {
            diag?.recordPerformError(error)
            return []
        }
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            diag?.recordCastFailure(request.results)
            return []
        }

        diag?.rawBoxes += observations.count
        if !observations.isEmpty { diag?.framesWithRaw += 1 }

        let rawW = Double(CVPixelBufferGetWidth(pixelBuffer))
        let rawH = Double(CVPixelBufferGetHeight(pixelBuffer))

        var out: [Candidate] = []
        for obs in observations {
            let score = Double(obs.confidence)
            guard score >= Self.farConf else {
                diag?.belowFloor += 1
                continue
            }
            // Vision box: normalized, origin bottom-left, in the *oriented* image.
            let box = obs.boundingBox
            let u = Double(box.midX)
            let v = 1.0 - Double(box.midY)  // → origin top-left
            let (rx, ry) = Self.orientedToRaw(u: u, v: v, orientation: orientation)
            let cx = rx * rawW
            let cy = ry * rawH

            // Radius: half the smaller box side in raw pixels (conservative disk).
            let (bw, bh) = Self.orientedSizeToRaw(
                w: Double(box.width), h: Double(box.height), orientation: orientation
            )
            var r = 0.5 * min(bw * rawW, bh * rawH)
            r = min(max(r, 6), 120)

            // Gate on the ball's extent, not just its center: hugging the gutter
            // (or a slightly-narrow calibration) puts the center up to a radius
            // outside the quad while the ball is still on the lane.
            let laneDist = geometry.signedDistanceToLane(CGPoint(x: cx, y: cy))
            guard laneDist >= -(LaneGeometry.laneMarginPx + r) else {
                diag?.recordLaneReject(x: cx, y: cy, confidence: score, distance: laneDist)
                continue
            }

            if score < Self.mainConf {
                let feet = geometry.feet(atImage: CGPoint(x: cx, y: cy + r))
                // Required confidence eases from MAIN_CONF at 15 ft to FAR_CONF
                // at FAR_FEET — the ball shrinks and blurs gradually (and scores
                // run lower on-device under FP16 than in full precision), so a
                // hard cliff drops legitimate mid-lane detections. First lock
                // still demands MAIN_CONF, so weak boxes can only continue an
                // existing track, never start one.
                let t = min(max((feet - 15.0) / (Self.farFeet - 15.0), 0), 1)
                let required = Self.mainConf + (Self.farConf - Self.mainConf) * t
                if score < required {
                    diag?.recordLowConfNear(feet: feet, confidence: score)
                    continue
                }
            }
            if let diag {
                diag.recordAccepted(
                    feet: geometry.feet(atImage: CGPoint(x: cx, y: cy + r)),
                    confidence: score
                )
            }
            out.append(Candidate(x: cx, y: cy, radius: r, confidence: score))
        }
        diag?.accepted += out.count
        return out
    }

    /// Map a normalized point (origin top-left) in the display-oriented image
    /// back into the raw buffer's normalized coordinates.
    static func orientedToRaw(u: Double, v: Double, orientation: CGImagePropertyOrientation) -> (Double, Double) {
        switch orientation {
        case .up: return (u, v)
        case .down: return (1 - u, 1 - v)
        case .right: return (v, 1 - u)   // raw rotated 90° CW for display
        case .left: return (1 - v, u)    // raw rotated 90° CCW for display
        default: return (u, v)
        }
    }

    /// Inverse of orientedToRaw: raw-buffer normalized point → display-oriented.
    static func rawToOriented(rx: Double, ry: Double, orientation: CGImagePropertyOrientation) -> (Double, Double) {
        switch orientation {
        case .up: return (rx, ry)
        case .down: return (1 - rx, 1 - ry)
        case .right: return (1 - ry, rx)
        case .left: return (ry, 1 - rx)
        default: return (rx, ry)
        }
    }

    static func orientedSizeToRaw(w: Double, h: Double, orientation: CGImagePropertyOrientation) -> (Double, Double) {
        switch orientation {
        case .right, .left: return (h, w)
        default: return (w, h)
        }
    }
}

/// Feeds the exported pipeline's threshold inputs — Vision otherwise runs with
/// the values baked in at export (conf 0.25), above the FAR_CONF floor the
/// detector's own filtering is designed around.
private final class ThresholdProvider: NSObject, MLFeatureProvider {
    var featureNames: Set<String> { ["confidenceThreshold", "iouThreshold"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "confidenceThreshold": return MLFeatureValue(double: BallDetector.farConf)
        case "iouThreshold": return MLFeatureValue(double: 0.45)
        default: return nil
        }
    }
}

/// Gate-by-gate counts across one analysis run, so a "couldn't track the ball"
/// failure names the stage that starved the tracker: the model saw nothing, the
/// lane gate rejected everything, or the confidence rules filtered it out.
final class DetectorDiagnostics {
    var frames = 0
    /// Frames where the model returned at least one box.
    var framesWithRaw = 0
    var rawBoxes = 0
    var belowFloor = 0
    var outsideLane = 0
    var lowConfNear = 0
    var accepted = 0
    /// Frames where the Vision request threw (normally swallowed silently).
    private(set) var performErrors = 0
    private(set) var firstPerformError: String?
    /// Frames where results weren't [VNRecognizedObjectObservation].
    private(set) var castFailures = 0
    private(set) var castFailureTypes: String?
    /// First few lane-gate rejections (raw-buffer pixels). A cluster of these
    /// tracing the ball's actual path means the quad is mis-mapped, not the
    /// model blind.
    private(set) var laneRejectSamples: [(x: Double, y: Double, confidence: Double, distance: Double)] = []

    func recordLaneReject(x: Double, y: Double, confidence: Double, distance: Double) {
        outsideLane += 1
        if laneRejectSamples.count < 8 {
            laneRejectSamples.append((x, y, confidence, distance))
        }
    }

    /// (feet, confidence) of low-conf rejections short of FAR_FEET — where on
    /// the lane the confidence cliff is losing the ball.
    private(set) var lowConfSamples: [(feet: Double, confidence: Double)] = []
    /// Accepted-box confidence by lane distance (10 ft buckets, last = 40+) —
    /// quantifies how detector confidence decays down-lane on this footage.
    private(set) var acceptedBuckets = [(sum: Double, n: Int)](repeating: (0, 0), count: 5)

    func recordAccepted(feet: Double, confidence: Double) {
        let b = min(max(Int(feet / 10.0), 0), 4)
        acceptedBuckets[b].sum += confidence
        acceptedBuckets[b].n += 1
    }

    func recordLowConfNear(feet: Double, confidence: Double) {
        lowConfNear += 1
        if lowConfSamples.count < 12 {
            lowConfSamples.append((feet, confidence))
        }
    }

    func recordPerformError(_ error: Error) {
        performErrors += 1
        if firstPerformError == nil { firstPerformError = "\(error)" }
    }

    func recordCastFailure(_ results: [Any]?) {
        castFailures += 1
        if castFailureTypes == nil {
            let types = (results ?? []).prefix(3).map { String(describing: type(of: $0)) }
            castFailureTypes = types.isEmpty ? "nil/empty results" : types.joined(separator: ", ")
        }
    }
}
