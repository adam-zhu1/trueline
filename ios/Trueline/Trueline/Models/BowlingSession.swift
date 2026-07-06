import Foundation
import SwiftData

/// One practice session: one phone placement, one calibration, many throws.
/// The tag fields follow the LaneTalk convention (ball / center / oil pattern)
/// and, with targetBoard, carry defaults so SwiftData migrations stay additive.
@Model
final class BowlingSession {
    var date: Date
    @Relationship(deleteRule: .nullify, inverse: \SavedShot.session)
    var shots: [SavedShot]
    /// What was thrown (e.g. "Phaze II").
    var ball: String = ""
    /// Where (bowling center name).
    var center: String = ""
    /// Oil pattern (e.g. "House", "Kegel Chameleon").
    var oilPattern: String = ""
    /// Target-line practice: the board at the arrows the bowler is aiming
    /// over; per-throw miss and session accuracy derive from it.
    var targetBoard: Double?

    init(date: Date = .now) {
        self.date = date
        shots = []
    }
}
