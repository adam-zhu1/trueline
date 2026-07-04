import Foundation
import SwiftData

/// One analyzed delivery, persisted: the metrics, the smoothed lane path, the
/// video-overlay trail, and (optionally) the replay video's file name in
/// ShotVideoStore. All post-1.0 fields carry defaults so SwiftData migrations
/// stay additive.
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
    /// Replay video in ShotVideoStore; nil when saving videos is off or the
    /// video was deleted from Settings.
    var videoFileName: String?
    /// Trail over the replay video, display-normalized (matches ShotResult.videoPath).
    var videoPathX: [Double] = []
    var videoPathY: [Double] = []
    var videoWidth: Double = 0
    var videoHeight: Double = 0

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
        videoPathX = result.videoPath.map { Double($0.x) }
        videoPathY = result.videoPath.map { Double($0.y) }
        videoWidth = Double(result.videoDisplaySize.width)
        videoHeight = Double(result.videoDisplaySize.height)
    }

    /// The replay video, when it was saved and still exists on disk.
    var videoURL: URL? {
        guard let videoFileName else { return nil }
        let url = ShotVideoStore.url(forName: videoFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Rebuild the value the lane view and replay overlay render from.
    var laneViewResult: ShotResult {
        ShotResult(
            speedMph: speedMph,
            arrowBoard: arrowBoard,
            breakpointBoard: breakpointBoard,
            breakpointFeet: breakpointFeet,
            entryAngleDegrees: entryAngleDegrees,
            entryBoard: entryBoard,
            path: zip(pathBoards, pathFeet).map { (board: $0, feet: $1) },
            videoPath: zip(videoPathX, videoPathY).map { CGPoint(x: $0, y: $1) },
            videoDisplaySize: CGSize(width: videoWidth, height: videoHeight),
            trackedFrames: pathBoards.count
        )
    }
}
