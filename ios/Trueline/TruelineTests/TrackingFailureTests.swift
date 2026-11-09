import Testing
@testable import Trueline

@Suite("Tracking failure reasons")
struct TrackingFailureTests {
    @Test func nothingDetectedMeansBallNotFound() {
        #expect(TrackingFailure.classify(rawBoxes: 0, outsideLane: 0, accepted: 0) == .ballNotFound)
    }

    /// Boxes the lane gate dropped outnumber the ones it kept: the outline
    /// is off, and that's the case new corners can fix.
    @Test func mostlyOutsideTheLaneMeansOffLane() {
        let failure = TrackingFailure.classify(rawBoxes: 40, outsideLane: 30, accepted: 4)
        #expect(failure == .offLane)
        #expect(failure.suggestsAdjustingCorners)
    }

    @Test func lowConfidenceOnlyMeansBallNotFound() {
        #expect(TrackingFailure.classify(rawBoxes: 12, outsideLane: 0, accepted: 0) == .ballNotFound)
    }

    @Test func acceptedButShortMeansLostEarly() {
        let failure = TrackingFailure.classify(rawBoxes: 20, outsideLane: 2, accepted: 15)
        #expect(failure == .lostEarly)
        #expect(!failure.suggestsAdjustingCorners)
    }

    @Test(arguments: [TrackingFailure.ballNotFound, .offLane, .lostEarly, .unreadableVideo])
    func copyStaysPlain(_ failure: TrackingFailure) {
        #expect(!failure.message.contains("\u{2014}"))
        #expect(!failure.title.isEmpty)
    }
}
