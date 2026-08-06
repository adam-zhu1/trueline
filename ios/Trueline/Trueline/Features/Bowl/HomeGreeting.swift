import Foundation

/// The Home mirror's varying headline. Every candidate is a true statement
/// computed from saved shots, ranked by newsworthiness; the last-shown
/// category is remembered so consecutive launches rotate instead of
/// repeating. Picked once per launch.
struct HomeGreeting: Equatable {
    enum Category: String {
        case away, record, milestone, pocket, delta, cadence
    }

    let category: Category
    let headline: String
    /// nil means the caller shows its cadence line instead.
    let subline: String?

    /// The line for this launch: best-ranked candidate, skipping the category
    /// shown last launch when there's an alternative.
    static func pick(
        shots: [SavedShot], now: Date = .now, defaults: UserDefaults = .standard
    ) -> HomeGreeting? {
        let ranked = candidates(shots: shots, now: now)
        guard !ranked.isEmpty else { return nil }
        let lastShown = defaults.string(forKey: "lastHomeGreeting")
        let choice = ranked.first { $0.category.rawValue != lastShown } ?? ranked[0]
        defaults.set(choice.category.rawValue, forKey: "lastHomeGreeting")
        return choice
    }

    /// Ranked candidates, best first. `shots` newest first (the home query's
    /// order).
    static func candidates(shots: [SavedShot], now: Date = .now) -> [HomeGreeting] {
        guard let latest = shots.first else { return [] }
        var result: [HomeGreeting] = []
        let calendar = Calendar.current

        // Away: three weeks without a throw reads as a return, not a streak.
        if let days = calendar.dateComponents([.day], from: latest.date, to: now).day,
           days >= 21 {
            result.append(HomeGreeting(
                category: .away,
                headline: "It's been a while.",
                subline: "Last threw \(latest.date.formatted(date: .abbreviated, time: .omitted))."
            ))
        }

        // "Last session": the latest shot's session, or that day's sessionless
        // imports.
        let lastSession: [SavedShot]
        if let session = latest.session {
            lastSession = session.shots
        } else {
            lastSession = shots.filter { calendar.isDate($0.date, inSameDayAs: latest.date) }
        }
        let lastSessionIDs = Set(lastSession.map { ObjectIdentifier($0) })
        let priorSpeeds = shots
            .filter { !lastSessionIDs.contains(ObjectIdentifier($0)) }
            .compactMap(\.speedMph)

        // Record: fastest ball ever, set in the last session, with enough
        // history that "fastest yet" means something.
        if let sessionTop = lastSession.compactMap(\.speedMph).max(),
           let bestBefore = priorSpeeds.max(),
           priorSpeeds.count >= 8, sessionTop > bestBefore {
            result.append(HomeGreeting(
                category: .record,
                headline: "New fastest ball.",
                subline: String(format: "%.1f mph last session.", sessionTop)
            ))
        }

        // Milestone: total measured throws, approaching or freshly past a mark.
        let total = shots.count
        let marks = [25, 50, 100, 150, 200, 300, 500, 750, 1000, 1500, 2000]
        if let next = marks.first(where: { $0 > total }), next - total <= 5, total >= 20 {
            result.append(HomeGreeting(
                category: .milestone,
                headline: "Throw \(next) coming up.",
                subline: "\(total) measured so far."
            ))
        } else if let passed = marks.last(where: { $0 <= total }),
                  total - passed < lastSession.count {
            result.append(HomeGreeting(
                category: .milestone,
                headline: "\(passed) throws measured.",
                subline: nil
            ))
        }

        // Pocket: a strong last session.
        let pockets = lastSession.filter(\.isPocketHit).count
        if pockets >= 3 {
            result.append(HomeGreeting(
                category: .pocket,
                headline: pockets == lastSession.count
                    ? "Every throw in the pocket."
                    : "\(pockets) pocket hits last session.",
                subline: nil
            ))
        }

        // Delta: the recent stretch is measurably quicker than the one before.
        let recent = shots.prefix(15).compactMap(\.speedMph)
        let earlier = shots.dropFirst(15).prefix(30).compactMap(\.speedMph)
        if recent.count >= 8, earlier.count >= 8 {
            let diff = recent.reduce(0, +) / Double(recent.count)
                - earlier.reduce(0, +) / Double(earlier.count)
            if diff >= 0.3 {
                result.append(HomeGreeting(
                    category: .delta,
                    headline: "Speed is up.",
                    subline: String(format: "Averaging %.1f mph faster lately.", diff)
                ))
            }
        }

        // Cadence: always available; the caller's cadence line fills the
        // subline.
        result.append(HomeGreeting(category: .cadence, headline: "Back at it.", subline: nil))
        return result
    }
}
