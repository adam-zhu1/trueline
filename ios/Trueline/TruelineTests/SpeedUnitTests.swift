import Foundation
import Testing
@testable import Trueline

@Suite("Speed unit display")
struct SpeedUnitTests {
    @Test func formatsInTheChosenUnit() {
        #expect(SpeedUnit.format(17.2, unit: "mph") == "17.2")
        #expect(SpeedUnit.format(17.2, unit: "kmh") == "27.7")
        #expect(SpeedUnit.format(nil, unit: "kmh") == "--")
        #expect(SpeedUnit.label("kmh") == "km/h")
        #expect(SpeedUnit.label("mph") == "mph")
    }

    /// Home's greeting used to print mph whatever the setting said.
    @Test func homeGreetingFollowsTheSetting() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func shot(_ mph: Double, daysAgo: Int) -> SavedShot {
            var result = AnalyzerVersionTests.result
            result.speedMph = mph
            return SavedShot(date: now.addingTimeInterval(-Double(daysAgo) * 86_400), result: result)
        }
        // Newest first: a new fastest ball today over nine slower ones.
        let shots = [shot(18, daysAgo: 0)] + (1...9).map { shot(16, daysAgo: $0) }

        let kmh = HomeGreeting.candidates(shots: shots, speedUnit: "kmh", now: now)
        #expect(kmh.first { $0.category == .record }?.subline == "29.0 km/h last session.")

        let mph = HomeGreeting.candidates(shots: shots, speedUnit: "mph", now: now)
        #expect(mph.first { $0.category == .record }?.subline == "18.0 mph last session.")
    }
}
