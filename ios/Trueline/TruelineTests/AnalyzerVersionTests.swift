import CoreGraphics
import SwiftData
import Testing
@testable import Trueline

@Suite("Analyzer version on saved shots")
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
        #expect(ShotAnalyzer.version == 2)
        #expect(!shot.isFromOlderAnalyzer)
    }

    @Test func versionOneShotsAreFlagged() {
        let shot = SavedShot(result: Self.result)
        shot.analyzerVersion = 1
        #expect(shot.isFromOlderAnalyzer)
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
        #expect(fetched.first?.analyzerVersion == 2)
    }
}
