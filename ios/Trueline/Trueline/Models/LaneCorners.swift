import CoreGraphics
import Foundation

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

    private static let lastConfirmedKey = "lastCalibration"

    /// The last human-confirmed calibration from a live session. Normalized
    /// coordinates, so it applies to any recording from the same placement —
    /// the next session starts from it and usually needs one confirming tap.
    static func loadLastConfirmed() -> LaneCorners? {
        guard let v = UserDefaults.standard.array(forKey: lastConfirmedKey) as? [Double],
              v.count == 8
        else { return nil }
        return LaneCorners(
            farLeft: CGPoint(x: v[0], y: v[1]),
            farRight: CGPoint(x: v[2], y: v[3]),
            nearRight: CGPoint(x: v[4], y: v[5]),
            nearLeft: CGPoint(x: v[6], y: v[7])
        )
    }

    func saveAsLastConfirmed() {
        UserDefaults.standard.set(
            [
                Double(farLeft.x), Double(farLeft.y),
                Double(farRight.x), Double(farRight.y),
                Double(nearRight.x), Double(nearRight.y),
                Double(nearLeft.x), Double(nearLeft.y),
            ],
            forKey: Self.lastConfirmedKey
        )
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
