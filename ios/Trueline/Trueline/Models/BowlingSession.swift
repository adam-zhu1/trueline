import Foundation
import SwiftData

/// One practice session: one phone placement, one calibration, many throws.
@Model
final class BowlingSession {
    var date: Date
    @Relationship(deleteRule: .nullify, inverse: \SavedShot.session)
    var shots: [SavedShot]

    init(date: Date = .now) {
        self.date = date
        shots = []
    }
}
