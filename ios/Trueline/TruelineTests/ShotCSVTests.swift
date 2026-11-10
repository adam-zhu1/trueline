import CoreGraphics
import Foundation
import Testing
@testable import Trueline

@Suite("CSV export")
struct ShotCSVTests {
    static let utc = TimeZone(identifier: "UTC")!

    static func shot(entry: Double?, at seconds: TimeInterval, version: Int = 2) -> SavedShot {
        let result = ShotResult(
            speedMph: 17.26, arrowBoard: 12.04, breakpointBoard: 7.5, breakpointFeet: 42,
            entryAngleDegrees: 5.06, entryBoard: entry,
            path: [], videoPath: [], videoDisplaySize: CGSize(width: 1080, height: 1920), trackedFrames: 40
        )
        let shot = SavedShot(date: Date(timeIntervalSince1970: seconds), result: result)
        shot.analyzerVersion = version
        return shot
    }

    @Test func headerThenOneRowPerShotOldestFirst() {
        let csv = ShotCSV.make(shots: [Self.shot(entry: 17.6, at: 120), Self.shot(entry: 18, at: 60)], timeZone: Self.utc)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines[0] == "date,session,speed_mph,board_at_arrows,breakpoint_board,breakpoint_ft,entry_board,entry_angle_deg,analyzer_version")
        #expect(lines[1] == "1970-01-01 00:01:00,,17.3,12.0,7.5,42.0,18.0,5.1,2")
        #expect(lines[2].hasPrefix("1970-01-01 00:02:00,"))
    }

    @Test func missingMetricsAreEmptyCells() {
        let csv = ShotCSV.make(shots: [Self.shot(entry: nil, at: 0, version: 1)], timeZone: Self.utc)
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row.hasSuffix(",5.1,1"))
        #expect(row.contains(",42.0,,5.1,"))
    }

    @Test func sessionColumnCarriesTheSessionStart() {
        let session = BowlingSession(date: Date(timeIntervalSince1970: 3600))
        let shot = Self.shot(entry: 17.5, at: 3700)
        shot.session = session
        let row = ShotCSV.make(shots: [shot], timeZone: Self.utc).components(separatedBy: "\r\n")[1]
        #expect(row.hasPrefix("1970-01-01 01:01:40,1970-01-01 01:00:00,"))
    }

    @Test func escaping() {
        #expect(ShotCSV.escape("plain") == "plain")
        #expect(ShotCSV.escape("a,b") == "\"a,b\"")
        #expect(ShotCSV.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(ShotCSV.escape("two\nlines") == "\"two\nlines\"")
        #expect(ShotCSV.escape("=SUM(A1)") == "'=SUM(A1)")
        #expect(ShotCSV.escape("-2.5") == "-2.5")
    }

    @Test func numbersIgnoreTheRegion() {
        #expect(ShotCSV.number(17.25) == "17.3" || ShotCSV.number(17.25) == "17.2")
        #expect(ShotCSV.number(nil) == "")
        #expect(ShotCSV.number(.nan) == "")
        #expect(!ShotCSV.number(1234.5).contains(","))
    }
}
