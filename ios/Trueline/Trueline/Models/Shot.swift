import Foundation

/// One analyzed delivery. For now this is a plain struct with mock data; persistence
/// (SwiftData/Core Data) comes in a later task.
struct Shot: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var speedMph: Double
    var boardAtArrows: Double
    var breakpointBoard: Double
    var entryAngleDegrees: Double
}

extension Shot {
    static let sampleData: [Shot] = [
        Shot(date: .now.addingTimeInterval(-300), speedMph: 17.2, boardAtArrows: 14.5, breakpointBoard: 6.8, entryAngleDegrees: 4.1),
        Shot(date: .now.addingTimeInterval(-600), speedMph: 16.8, boardAtArrows: 15.1, breakpointBoard: 7.2, entryAngleDegrees: 3.7),
        Shot(date: .now.addingTimeInterval(-900), speedMph: 17.5, boardAtArrows: 13.9, breakpointBoard: 6.2, entryAngleDegrees: 4.5),
    ]
}
