import Testing
@testable import Trueline

@Suite("Capture routing gate")
struct ReviewRouteTests {
    @Test func outOfFreeThrowsAlwaysHitsThePaywall() {
        for recalibrating in [false, true] {
            for corners in [false, true] {
                #expect(ReviewRoute.next(
                    canAnalyze: false, recalibrating: recalibrating, hasSessionCorners: corners
                ) == .paywall)
            }
        }
    }

    @Test func recalibrateGoesToCalibration() {
        #expect(ReviewRoute.next(canAnalyze: true, recalibrating: true, hasSessionCorners: true) == .calibrate)
    }

    @Test func useReusesSessionCornersWhenPresent() {
        #expect(ReviewRoute.next(canAnalyze: true, recalibrating: false, hasSessionCorners: true) == .analyze)
        #expect(ReviewRoute.next(canAnalyze: true, recalibrating: false, hasSessionCorners: false) == .calibrate)
    }
}
