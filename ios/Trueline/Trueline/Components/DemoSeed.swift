#if DEBUG
import CoreGraphics
import Foundation
import SwiftData

/// Debug hook: launch with `-seedDemoHistory` to populate History with five
/// plausible practice sessions (improving trend, two balls) — the simulator
/// can't bowl, and Trends/History screens need data to be inspectable. No-op
/// when any session already exists, so it never doubles up.
enum DemoSeed {
    static func seedIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemoHistory") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<BowlingSession>())) ?? 0
        guard existing == 0 else { return }

        var rng = SeededRNG(state: 0x5EED)
        // `-seedDemoEvening` dates the sessions on league nights (7:30 PM,
        // newest yesterday) so screenshots don't read as morning practice.
        var anchor = Date.now
        if UserDefaults.standard.bool(forKey: "seedDemoEvening"),
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now),
           let evening = Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: yesterday) {
            anchor = evening
        }
        let balls = ["Phaze II", "Phaze II", "Hustle", "Phaze II", "Hustle"]
        for index in 0..<5 {
            let session = BowlingSession(
                date: Calendar.current.date(byAdding: .day, value: -7 * (4 - index), to: anchor) ?? anchor
            )
            session.ball = balls[index]
            session.center = "Kingpin Lanes"
            session.oilPattern = "House"
            context.insert(session)

            // Later sessions tighten: spreads shrink and entry angle drifts
            // up through the 4–6° band. Pocket hits are dealt, not drawn, so
            // every night lands at a league bowler's 50 to 67% instead of a
            // small-sample 0; the last throw of a night is always a strike
            // line, which keeps the newest shot a clean screenshot.
            let skill = Double(index) / 4.0
            let count = 5 + index % 3
            let hits = pocketHits[index]
            var misses = Set<Int>()
            while misses.count < count - hits {
                misses.insert(Int.random(in: 0..<(count - 1), using: &rng))
            }
            for throwIndex in 0..<count {
                let shot = SavedShot(
                    // A throw every seven minutes or so, in order.
                    date: session.date.addingTimeInterval(
                        Double(throwIndex) * 420 + Double.random(in: 0...120, using: &rng)
                    ),
                    result: makeResult(skill: skill, pocket: !misses.contains(throwIndex), rng: &rng)
                )
                shot.session = session
                context.insert(shot)
            }
        }

        // Sessionless imports with a shot-level ball tag — the analyze-
        // existing-footage path that per-ball stats must include.
        // One in the pocket and one out, so the spare ball doesn't top the
        // per-ball pocket bars at 100%.
        for (daysAgo, pocket) in [(3, true), (10, false)] {
            let shot = SavedShot(
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: anchor) ?? anchor,
                result: makeResult(skill: 0.5, pocket: pocket, rng: &rng)
            )
            shot.ball = "Spare Ball"
            context.insert(shot)
        }
    }

    /// Pocket hits per session, oldest first, against 5, 6, 7, 5 and 6
    /// throws: 60, 50, 57, 60 and 67%.
    private static let pocketHits = [3, 3, 4, 3, 4]

    /// `pocket` deals the throw into the 17–18 pocket or a board or two
    /// either side of it.
    private static func makeResult(skill: Double, pocket: Bool, rng: inout SeededRNG) -> ShotResult {
        func jitter(_ spread: Double) -> Double {
            Double.random(in: -spread...spread, using: &rng)
        }
        let entryBoard: Double
        if pocket {
            entryBoard = 17.5 + jitter(0.45)
        } else {
            let side: Double = Bool.random(using: &rng) ? 1 : -1
            entryBoard = 17.5 + side * Double.random(in: 0.8...1.9, using: &rng)
        }
        let breakpointBoard = 7.0 + jitter(1.0)
        let speed = 17.0 + 0.4 * skill + jitter(0.9 - 0.4 * skill)
        let entryAngle = 4.0 + 1.0 * skill + jitter(0.6)

        // Overlay path: the brand hook nudged laterally per shot, so the
        // session "Lines" view fans realistically.
        let lateral = entryBoard - 17.5
        let path: [(board: Double, feet: Double)] = (0...30).map { step in
            let u = Double(step) / 30
            return (board: HookCurve.board(at: u) + lateral, feet: u * 60)
        }

        // Same draw order as before, so the seed's numbers don't shift.
        let arrowBoard = 11.5 + jitter(1.5 - 0.7 * skill)
        let breakpointFeet = 40.0 + jitter(2.0)
        // Outward launch of a few degrees, like the seeded path's skid leg.
        let launchAngle = 1.9 + jitter(0.7 - 0.3 * skill)
        // Derived, not drawn: the launch line walked back 15 ft to the foul
        // line, and a whole-lane average a bit under launch speed.
        let foulLineBoard = arrowBoard + tan(launchAngle * .pi / 180) * 180 / LaneModel.inchesPerBoard
        let averageSpeed = speed - 1.6
        let shotTime = 59.5 / (averageSpeed * 5280 / 3600)

        return ShotResult(
            speedMph: speed,
            arrowBoard: arrowBoard,
            breakpointBoard: breakpointBoard,
            breakpointFeet: breakpointFeet,
            entryAngleDegrees: entryAngle,
            entryBoard: entryBoard,
            launchAngleDegrees: launchAngle,
            foulLineBoard: foulLineBoard,
            averageSpeedMph: averageSpeed,
            shotTimeSeconds: shotTime,
            // The Settings hand, so `-bowlingHand left` seeds a lefty history.
            hand: .setting,
            path: path,
            videoPath: [],
            videoDisplaySize: .zero,
            trackedFrames: path.count
        )
    }

    /// Deterministic: the same seed yields the same demo history, so
    /// screenshots are reproducible run to run.
    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }
}
#endif
