import Foundation

/// Metrics derived from the analyzer's outputs — UI-layer math on values the
/// pipeline already produces, so the Analysis/ parity surface stays untouched.
extension ShotResult {
    /// The strike pocket, as an entry-board range from the bowler's side.
    /// One definition shared by the results tile, session pocket counts, and
    /// the trends chart.
    static let pocketBoards: ClosedRange<Double> = 17...18

    /// Boards of lateral travel from the breakpoint to the pins — the one
    /// number for "how much did it hook." abs() so a backup ball reads as
    /// hook rather than negative hook.
    var hookBoards: Double? {
        guard let entryBoard, let breakpointBoard else { return nil }
        return abs(entryBoard - breakpointBoard)
    }
}

extension SavedShot {
    var hookBoards: Double? {
        guard let entryBoard, let breakpointBoard else { return nil }
        return abs(entryBoard - breakpointBoard)
    }

    var isPocketHit: Bool {
        entryBoard.map { ShotResult.pocketBoards.contains($0) } ?? false
    }

    /// The ball this shot was thrown with: its own tag first, else the
    /// session's — so per-ball stats see session throws and one-off imports
    /// through one lens.
    var effectiveBall: String {
        ball.isEmpty ? (session?.ball ?? "") : ball
    }
}

/// The balls recently tagged on shots, most recent first — feeds the results
/// screen's quick picker so a league bowler taps instead of retyping.
enum RecentBalls {
    private static let key = "recentBalls"
    static let limit = 6

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func noteUsed(_ ball: String) {
        let trimmed = ball.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var balls = load().filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        balls.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(balls.prefix(limit)), forKey: key)
    }
}
