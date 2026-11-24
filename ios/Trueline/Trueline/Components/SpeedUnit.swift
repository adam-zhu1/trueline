import Foundation

/// Speeds are stored and computed in mph everywhere (parity with the
/// prototype and the pro benchmarks); the km/h preference converts at
/// display time only.
enum SpeedUnit {
    static let kmhPerMph = 1.60934

    static func value(_ mph: Double, unit: String) -> Double {
        unit == "kmh" ? mph * kmhPerMph : mph
    }

    static func label(_ unit: String) -> String {
        unit == "kmh" ? "km/h" : "mph"
    }

    /// A stored mph reading as display text in the unit, one decimal, or
    /// "--" when there is no reading.
    static func format(_ mph: Double?, unit: String) -> String {
        guard let mph else { return "--" }
        return String(format: "%.1f", value(mph, unit: unit))
    }
}
