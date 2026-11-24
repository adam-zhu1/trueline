import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import Trueline

/// Serialized: the legacy-shape stores below declare their own `SavedShot`
/// entity, and SwiftData resolves entities by name, so a container opened
/// alongside one of them can pick up the legacy shape and drop the newer
/// fields on insert.
@Suite("Analyzer version on saved shots", .serialized)
struct AnalyzerVersionTests {
    static let result = ShotResult(
        speedMph: 17.2, arrowBoard: 12.0, breakpointBoard: 7.5, breakpointFeet: 42,
        entryAngleDegrees: 5.1, entryBoard: 17.6, launchAngleDegrees: 1.8,
        foulLineBoard: 15.0, averageSpeedMph: 16.4, shotTimeSeconds: 2.6, hookFactor: 3.1,
        path: [(board: 15.0, feet: 0), (board: 7.5, feet: 42), (board: 17.6, feet: 60)],
        videoPath: [], videoDisplaySize: CGSize(width: 1080, height: 1920), trackedFrames: 3
    )

    @Test func newShotsCarryTheCurrentAnalyzer() {
        let shot = SavedShot(result: Self.result)
        #expect(shot.analyzerVersion == ShotAnalyzer.version)
        #expect(ShotAnalyzer.version == 3)
        #expect(!shot.isFromOlderAnalyzer)
    }

    /// 1 is TrueLine 1.0; 2 is the interim 1.1 builds that still read
    /// metrics off the Kalman state. Both get the "1.0 tracker" tag.
    @Test("versions 1 and 2 are flagged, 3 is not", arguments: [(1, true), (2, true), (3, false)])
    func versionGate(version: Int, flagged: Bool) {
        let shot = SavedShot(result: Self.result)
        shot.analyzerVersion = version
        #expect(shot.isFromOlderAnalyzer == flagged)
    }

    @Test func olderShotsShareOneQuietLabel() {
        #expect(OlderTracker.label == "1.0 tracker")
        #expect(!OlderTracker.note.contains("—"))
    }

    /// Stores written by 1.0 have no analyzerVersion column; lightweight
    /// migration fills it from the schema default, which must be 1.
    @Test func schemaDefaultMarksMigratedShotsAsVersionOne() throws {
        let entity = try #require(Schema([SavedShot.self]).entities.first { $0.name == "SavedShot" })
        let attribute = try #require(entity.attributes.first { $0.name == "analyzerVersion" })
        #expect(attribute.defaultValue as? Int == 1)
    }

    @Test func versionSurvivesARoundTripThroughTheStore() throws {
        let container = try ModelContainer(
            for: SavedShot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(SavedShot(result: Self.result))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<SavedShot>())
        #expect(fetched.first?.analyzerVersion == 3)
        #expect(fetched.first?.bowlingHand == "right")
    }

    // MARK: - Calibration kept for re-analysis

    static let corners = LaneCorners(
        farLeft: CGPoint(x: 0.41, y: 0.22),
        farRight: CGPoint(x: 0.57, y: 0.22),
        nearRight: CGPoint(x: 0.93, y: 0.88),
        nearLeft: CGPoint(x: 0.08, y: 0.88)
    )

    static var calibratedResult: ShotResult {
        var result = Self.result
        result.corners = Self.corners
        result.captureZoom = 2
        return result
    }

    @Test func cornersFlattenAndRebuild() {
        let flat = Self.corners.flattened
        #expect(flat == [0.41, 0.22, 0.57, 0.22, 0.93, 0.88, 0.08, 0.88])
        #expect(LaneCorners(flattened: flat) == Self.corners)
        #expect(LaneCorners(flattened: []) == nil)
        #expect(LaneCorners(flattened: Array(flat.dropLast())) == nil)
    }

    @Test func newShotsKeepTheirCalibration() {
        let shot = SavedShot(result: Self.calibratedResult)
        #expect(shot.calibration == Self.corners)
        #expect(shot.calibrationZoom == 2)
        // Set by the save flow once a replay is stored.
        #expect(shot.videoTrimStartSeconds == nil)
    }

    /// An imported clip: corners, but no capture zoom.
    @Test func importedShotsKeepCornersWithoutZoom() {
        var result = Self.result
        result.corners = Self.corners
        let shot = SavedShot(result: result)
        #expect(shot.calibration == Self.corners)
        #expect(shot.calibrationZoom == nil)
    }

    @Test func calibrationSurvivesARoundTripThroughTheStore() throws {
        let container = try ModelContainer(
            for: SavedShot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let shot = SavedShot(result: Self.calibratedResult)
        shot.videoTrimStartSeconds = 3.25
        context.insert(shot)
        try context.save()
        let fetched = try #require(try context.fetch(FetchDescriptor<SavedShot>()).first)
        #expect(fetched.calibration == Self.corners)
        #expect(fetched.calibrationZoom == 2)
        #expect(fetched.videoTrimStartSeconds == 3.25)
    }

    // MARK: - Opening stores written by older builds

    private static func storeURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnalyzerVersionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("default.store")
    }

    private static func openWithCurrentSchema(_ url: URL) throws -> [SavedShot] {
        let container = try ModelContainer(
            for: SavedShot.self,
            configurations: ModelConfiguration(url: url)
        )
        return try ModelContext(container).fetch(FetchDescriptor<SavedShot>())
    }

    /// A 1.0 store: no analyzerVersion, no hand. Opening it with today's
    /// schema must keep the shot, mark it version 1 and leave the hand empty
    /// (drawn with the Settings hand).
    @Test func versionOneStoreMigrates() throws {
        let url = try Self.storeURL()
        do {
            let container = try ModelContainer(
                for: Schema([StoreV1.SavedShot.self]),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            context.insert(StoreV1.SavedShot(speedMph: 16.8, entryBoard: 17.1))
            try context.save()
        }
        let shots = try Self.openWithCurrentSchema(url)
        let shot = try #require(shots.first)
        #expect(shots.count == 1)
        #expect(shot.speedMph == 16.8)
        #expect(shot.entryBoard == 17.1)
        #expect(shot.analyzerVersion == 1)
        #expect(shot.isFromOlderAnalyzer)
        #expect(shot.bowlingHand == "")
        Self.expectNoCalibration(shot)
    }

    /// Older shots open with no calibration: nothing to re-run from.
    private static func expectNoCalibration(_ shot: SavedShot) {
        #expect(shot.calibrationCorners.isEmpty)
        #expect(shot.calibration == nil)
        #expect(shot.calibrationZoom == nil)
        #expect(shot.videoTrimStartSeconds == nil)
    }

    /// An interim 1.1 store: analyzerVersion 2, no hand column yet.
    @Test func versionTwoStoreMigrates() throws {
        let url = try Self.storeURL()
        do {
            let container = try ModelContainer(
                for: Schema([StoreV2.SavedShot.self]),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            context.insert(StoreV2.SavedShot(speedMph: 17.4, entryBoard: 17.6, analyzerVersion: 2))
            try context.save()
        }
        let shots = try Self.openWithCurrentSchema(url)
        let shot = try #require(shots.first)
        #expect(shot.speedMph == 17.4)
        #expect(shot.analyzerVersion == 2)
        #expect(shot.isFromOlderAnalyzer)
        #expect(shot.bowlingHand == "")
        Self.expectNoCalibration(shot)
    }

    /// A 1.1 store from before calibration was kept: version 3, a stored
    /// hand and a replay, no corners.
    @Test func versionThreeStoreWithoutCalibrationMigrates() throws {
        let url = try Self.storeURL()
        do {
            let container = try ModelContainer(
                for: Schema([StoreV3.SavedShot.self]),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(container)
            context.insert(StoreV3.SavedShot(speedMph: 17.9, entryBoard: 17.4))
            try context.save()
        }
        let shots = try Self.openWithCurrentSchema(url)
        let shot = try #require(shots.first)
        #expect(shot.speedMph == 17.9)
        #expect(shot.analyzerVersion == 3)
        #expect(!shot.isFromOlderAnalyzer)
        #expect(shot.bowlingHand == "left")
        #expect(shot.videoFileName == "shot-legacy.mp4")
        Self.expectNoCalibration(shot)
    }
}

/// The saved-shot shape TrueLine 1.0 wrote, trimmed to the fields that matter
/// here (every later field is optional or defaulted, so it migrates the same).
enum StoreV1 {
    @Model
    final class SavedShot {
        var date: Date
        var speedMph: Double?
        var entryBoard: Double?
        var pathBoards: [Double]
        var pathFeet: [Double]

        init(speedMph: Double?, entryBoard: Double?) {
            date = .now
            self.speedMph = speedMph
            self.entryBoard = entryBoard
            pathBoards = [15, 17]
            pathFeet = [0, 60]
        }
    }
}

/// The interim 1.1 shape: analyzerVersion but no stored hand.
enum StoreV2 {
    @Model
    final class SavedShot {
        var date: Date
        var speedMph: Double?
        var entryBoard: Double?
        var pathBoards: [Double]
        var pathFeet: [Double]
        var analyzerVersion: Int = 1

        init(speedMph: Double?, entryBoard: Double?, analyzerVersion: Int) {
            date = .now
            self.speedMph = speedMph
            self.entryBoard = entryBoard
            pathBoards = [15, 17]
            pathFeet = [0, 60]
            self.analyzerVersion = analyzerVersion
        }
    }
}

/// The 1.1 shape before calibration was kept: version 3 and a stored hand.
enum StoreV3 {
    @Model
    final class SavedShot {
        var date: Date
        var speedMph: Double?
        var entryBoard: Double?
        var pathBoards: [Double]
        var pathFeet: [Double]
        var videoFileName: String?
        var analyzerVersion: Int = 1
        var bowlingHand: String = ""

        init(speedMph: Double?, entryBoard: Double?) {
            date = .now
            self.speedMph = speedMph
            self.entryBoard = entryBoard
            pathBoards = [15, 17]
            pathFeet = [0, 60]
            videoFileName = "shot-legacy.mp4"
            analyzerVersion = 3
            bowlingHand = "left"
        }
    }
}
