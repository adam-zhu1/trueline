import CoreGraphics
import Foundation
import Testing
@testable import Trueline

@Suite("CSV export")
struct ShotCSVTests {
    static let utc = TimeZone(identifier: "UTC")!

    static func shot(entry: Double?, at seconds: TimeInterval, version: Int = 2, full: Bool = false) -> SavedShot {
        let result = ShotResult(
            speedMph: 17.26, arrowBoard: 12.04, breakpointBoard: 7.5, breakpointFeet: 42,
            entryAngleDegrees: 5.06, entryBoard: entry,
            launchAngleDegrees: full ? -1.84 : nil, foulLineBoard: full ? 15.04 : nil,
            averageSpeedMph: full ? 16.43 : nil, shotTimeSeconds: full ? 2.567 : nil,
            hookFactor: full ? 3.1 : nil,
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
        #expect(lines[0] == "date,session,launch_speed_mph,board_at_arrows,breakpoint_board,breakpoint_ft,entry_board,entry_angle_deg,analyzer_version,foul_line_board,launch_angle_deg,hook_boards,average_speed_mph,shot_time_s")
        // A 1.0-era shot: the 1.1 columns are empty except hook, which is
        // derived from breakpoint and entry.
        #expect(lines[1] == "1970-01-01 00:01:00,,17.3,12.0,7.5,42.0,18.0,5.1,2,,,10.5,,")
        #expect(lines[2].hasPrefix("1970-01-01 00:02:00,"))
    }

    @Test func missingMetricsAreEmptyCells() {
        let csv = ShotCSV.make(shots: [Self.shot(entry: nil, at: 0, version: 1)], timeZone: Self.utc)
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row.hasSuffix(",5.1,1,,,,,"))
        #expect(row.contains(",42.0,,5.1,"))
    }

    @Test func newMetricsAppendAfterTheOriginalColumns() {
        let csv = ShotCSV.make(shots: [Self.shot(entry: 17.5, at: 0, full: true)], timeZone: Self.utc)
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[1] == "1970-01-01 00:00:00,,17.3,12.0,7.5,42.0,17.5,5.1,2,15.0,-1.8,10.0,16.4,2.57")
        // The 1.0 columns keep their positions.
        let header = lines[0].components(separatedBy: ",")
        #expect(Array(header.prefix(9)).dropFirst(3) == ["board_at_arrows", "breakpoint_board", "breakpoint_ft", "entry_board", "entry_angle_deg", "analyzer_version"])
        #expect(!header.contains("hook_factor"))
    }

    @Test func speedsFollowTheUnitSetting() {
        let csv = ShotCSV.make(shots: [Self.shot(entry: 17.5, at: 0, full: true)], speedUnit: "kmh", timeZone: Self.utc)
        let lines = csv.components(separatedBy: "\r\n")
        let header = lines[0].components(separatedBy: ",")
        let row = lines[1].components(separatedBy: ",")
        #expect(header[2] == "launch_speed_kmh")
        #expect(header[12] == "average_speed_kmh")
        #expect(!lines[0].contains("mph"))
        #expect(row[2] == "27.8")   // 17.26 mph
        #expect(row[12] == "26.4")  // 16.43 mph
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
