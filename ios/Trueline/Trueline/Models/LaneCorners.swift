import CoreGraphics

/// The four lane corners in normalized image coordinates (0–1, origin top-left).
/// Near = foul line, far = pin deck. This quad defines the perspective transform
/// the analysis pipeline uses to map the camera view onto the lane.
struct LaneCorners: Equatable {
    var farLeft: CGPoint
    var farRight: CGPoint
    var nearRight: CGPoint
    var nearLeft: CGPoint

    /// Order traces the quad outline (far pair left→right, then near pair right→left).
    enum Corner: CaseIterable, Hashable {
        case farLeft, farRight, nearRight, nearLeft
    }

    subscript(corner: Corner) -> CGPoint {
        get {
            switch corner {
            case .farLeft: farLeft
            case .farRight: farRight
            case .nearRight: nearRight
            case .nearLeft: nearLeft
            }
        }
        set {
            switch corner {
            case .farLeft: farLeft = newValue
            case .farRight: farRight = newValue
            case .nearRight: nearRight = newValue
            case .nearLeft: nearLeft = newValue
            }
        }
    }

    /// Same trapezoid as the record screen's framing guide — a sensible seed until
    /// lane auto-detect (task #4) proposes real corners.
    static let defaultGuess = LaneCorners(
        farLeft: CGPoint(x: 0.38, y: 0.35),
        farRight: CGPoint(x: 0.62, y: 0.35),
        nearRight: CGPoint(x: 0.85, y: 0.95),
        nearLeft: CGPoint(x: 0.15, y: 0.95)
    )
}
