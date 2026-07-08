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
        let balls = ["Phaze II", "Phaze II", "Hustle", "Phaze II", "Hustle"]
        for index in 0..<5 {
            let session = BowlingSession(
                date: Calendar.current.date(byAdding: .day, value: -7 * (4 - index), to: .now) ?? .now
            )
            session.ball = balls[index]
            session.center = "Kingpin Lanes"
            session.oilPattern = "House"
            context.insert(session)

            // Later sessions tighten: spreads shrink, entry angle drifts into
            // the 4–6° band, more throws find the pocket.
            let skill = Double(index) / 4.0
            for _ in 0..<(5 + index % 3) {
                let shot = SavedShot(
                    date: session.date.addingTimeInterval(Double.random(in: 0...3600, using: &rng)),
                    result: makeResult(skill: skill, rng: &rng)
                )
                shot.session = session
                context.insert(shot)
            }
        }
    }

    private static func makeResult(skill: Double, rng: inout SeededRNG) -> ShotResult {
        func jitter(_ spread: Double) -> Double {
            Double.random(in: -spread...spread, using: &rng)
        }
        let entrySpread = 1.8 - 1.2 * skill
        let entryBoard = 17.5 + jitter(entrySpread)
        let breakpointBoard = 7.0 + jitter(1.0)
        let speed = 16.2 + 0.4 * skill + jitter(1.0 - 0.5 * skill)
        let entryAngle = 3.6 + 1.2 * skill + jitter(0.8)

        // Overlay path: the brand hook nudged laterally per shot, so the
        // session "Lines" view fans realistically.
        let lateral = entryBoard - 17.5
        let path: [(board: Double, feet: Double)] = (0...30).map { step in
            let u = Double(step) / 30
            return (board: HookCurve.board(at: u) + lateral, feet: u * 60)
        }

        return ShotResult(
            speedMph: speed,
            arrowBoard: 10.0 + jitter(1.5 - 0.7 * skill),
            breakpointBoard: breakpointBoard,
            breakpointFeet: 40.0 + jitter(2.0),
            entryAngleDegrees: entryAngle,
            entryBoard: entryBoard,
            launchAngleDegrees: 15.0 + jitter(1.2),
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
