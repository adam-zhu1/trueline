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
    }

    /// Candidates in raw-buffer pixel coordinates. `orientation` tells Vision how
    /// the buffer maps to display-upright so the model sees what it trained on;
    /// returned boxes are converted back to raw coordinates for the tracker.
    func candidates(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        geometry: LaneGeometry
    ) -> [Candidate] {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        guard (try? handler.perform([request])) != nil,
              let observations = request.results as? [VNRecognizedObjectObservation]
        else { return [] }

        let rawW = Double(CVPixelBufferGetWidth(pixelBuffer))
        let rawH = Double(CVPixelBufferGetHeight(pixelBuffer))

        var out: [Candidate] = []
        for obs in observations {
            let score = Double(obs.confidence)
            guard score >= Self.farConf else { continue }
            // Vision box: normalized, origin bottom-left, in the *oriented* image.
            let box = obs.boundingBox
            let u = Double(box.midX)
            let v = 1.0 - Double(box.midY)  // → origin top-left
            let (rx, ry) = Self.orientedToRaw(u: u, v: v, orientation: orientation)
            let cx = rx * rawW
            let cy = ry * rawH
            guard geometry.signedDistanceToLane(CGPoint(x: cx, y: cy)) >= -LaneGeometry.laneMarginPx
            else { continue }

            // Radius: half the smaller box side in raw pixels (conservative disk).
            let (bw, bh) = Self.orientedSizeToRaw(
                w: Double(box.width), h: Double(box.height), orientation: orientation
            )
            var r = 0.5 * min(bw * rawW, bh * rawH)
            r = min(max(r, 6), 120)

            if score < Self.mainConf {
                // Low score only acceptable deep down-lane among the pins.
                let feet = geometry.feet(atImage: CGPoint(x: cx, y: cy + r))
                if feet < Self.farFeet { continue }
            }
            out.append(Candidate(x: cx, y: cy, radius: r, confidence: score))
        }
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

    static func orientedSizeToRaw(w: Double, h: Double, orientation: CGImagePropertyOrientation) -> (Double, Double) {
        switch orientation {
        case .right, .left: return (h, w)
        default: return (w, h)
        }
    }
}
