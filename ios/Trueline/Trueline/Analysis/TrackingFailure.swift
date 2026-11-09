import Foundation

/// Why a throw couldn't be measured, in terms the bowler can act on. Derived
/// from the detector's gate counts, which used to reach only the debug
/// console, so the failure screen can say what happened to this throw
/// instead of listing every possible cause.
enum TrackingFailure: Equatable {
    /// The detector found nothing that looked like a ball on the lane.
    case ballNotFound
    /// Ball-like boxes appeared, but mostly outside the calibrated lane: the
    /// outline no longer matches where the lane is in the frame.
    case offLane
    /// The ball was found but never held long enough to measure.
    case lostEarly
    /// The clip itself couldn't be read.
    case unreadableVideo

    /// `accepted` counts boxes that passed every gate; `outsideLane` the ones
    /// the lane gate dropped. The order matters: a calibration that misses
    /// the lane shows up as "outside lane" even though the model saw the ball.
    static func classify(rawBoxes: Int, outsideLane: Int, accepted: Int) -> TrackingFailure {
        if rawBoxes == 0 { return .ballNotFound }
        if outsideLane > accepted { return .offLane }
        if accepted == 0 { return .ballNotFound }
        return .lostEarly
    }

    var title: String {
        switch self {
        case .ballNotFound: "The ball wasn't found"
        case .offLane: "The lane outline doesn't match"
        case .lostEarly: "The ball was lost too early"
        case .unreadableVideo: "This video couldn't be read"
        }
    }

    var message: String {
        switch self {
        case .ballNotFound:
            "Nothing in this clip looked like a ball on the lane. Check that the whole lane is in view and the throw starts after recording does."
        case .offLane:
            "The ball showed up outside the lane you calibrated, which usually means the phone moved. Adjust the corners to match the lane and try again."
        case .lostEarly:
            "The ball was spotted but not followed far enough to measure. Someone crossing the view or a ball that blends into the lane can cause this. Try another throw."
        case .unreadableVideo:
            "Something went wrong opening the recording. Record the throw again."
        }
    }

    /// Off-lane is the one case that new corners can fix; the rest need a
    /// new recording.
    var suggestsAdjustingCorners: Bool { self == .offLane }
}
