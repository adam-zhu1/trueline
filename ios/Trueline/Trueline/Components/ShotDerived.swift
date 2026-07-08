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
}
