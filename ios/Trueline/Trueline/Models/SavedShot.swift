import Foundation
import SwiftData

/// One analyzed delivery, persisted. Stores the metrics and the smoothed lane
/// path (a few hundred doubles) — not the video, which stays in temp and gets
/// purged by the system, so History costs no meaningful storage.
@Model
final class SavedShot {
    var date: Date
    var speedMph: Double?
    var arrowBoard: Double?
    var breakpointBoard: Double?
    var breakpointFeet: Double?
    var entryAngleDegrees: Double?
    var entryBoard: Double?
    var pathBoards: [Double]
    var pathFeet: [Double]
    var session: BowlingSession?

    init(date: Date = .now, result: ShotResult) {
        self.date = date
        speedMph = result.speedMph
        arrowBoard = result.arrowBoard
        breakpointBoard = result.breakpointBoard
        breakpointFeet = result.breakpointFeet
        entryAngleDegrees = result.entryAngleDegrees
        entryBoard = result.entryBoard
        pathBoards = result.path.map(\.board)
        pathFeet = result.path.map(\.feet)
    }

    /// Rebuild the value the lane view renders from.
    var laneViewResult: ShotResult {
        ShotResult(
            speedMph: speedMph,
            arrowBoard: arrowBoard,
            breakpointBoard: breakpointBoard,
            breakpointFeet: breakpointFeet,
            entryAngleDegrees: entryAngleDegrees,
            entryBoard: entryBoard,
            path: zip(pathBoards, pathFeet).map { (board: $0, feet: $1) },
            videoPath: [],
            videoDisplaySize: .zero,
            trackedFrames: pathBoards.count
        )
    }
}
