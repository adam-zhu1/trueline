import Foundation

/// What one analysis did, sample by sample: the tracked ball (Kalman state,
/// raw buffer pixels), the detector box behind each measured sample, and the
/// gate counts. The app ignores it; the Mac accuracy benchmark
/// (experiments/accuracy_bench) compares it against hand-labelled frames.
struct AnalysisTrace: Codable {
    struct Sample: Codable {
        /// 1-based decoded frame index.
        var frame: Int
        /// Tracked ball center and radius, raw buffer pixels.
        var x: Double
        var y: Double
        var radius: Double
        /// Lane position of the sample's contact point.
        var board: Double
        var feet: Double
        /// Detector box center/radius (raw px) and confidence; nil on coasted
        /// (prediction-only) frames.
        var detectionX: Double?
        var detectionY: Double?
        var detectionRadius: Double?
        var confidence: Double?
        /// The detection after refineCenter, before smoothing (raw px).
        var refinedX: Double?
        var refinedY: Double?
    }

    var fps: Double
    /// CGImagePropertyOrientation raw value of the clip.
    var orientation: UInt32
    var samples: [Sample]
    var framesDecoded: Int
    var rawBoxes: Int
    var belowFloor: Int
    var outsideLane: Int
    var lowConfNear: Int
    var accepted: Int
    var measured: Int
    var coasted: Int
    var associationRejects: Int
    var trackResets: Int
    var focusHits: Int
}
