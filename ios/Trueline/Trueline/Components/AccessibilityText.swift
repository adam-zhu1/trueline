import Foundation

/// Spoken text for VoiceOver. The screens show numbers with compact unit
/// glyphs ("°", "ft", "boards/s²") that read badly aloud, and the drawings
/// (lane view, home hero) carry information VoiceOver can't see at all. These
/// builders turn both into one plain sentence per element, and are pure so
/// they can be unit tested.
enum AccessibilityText {
    /// Unit glyph as it should be spoken, singular or plural by value.
    static func spokenUnit(_ unit: String, value: Double?) -> String {
        let one = value.map { abs($0 - 1) < 0.0001 } ?? false
        switch unit {
        case "°": return one ? "degree" : "degrees"
        case "ft": return one ? "foot" : "feet"
        case "s": return one ? "second" : "seconds"
        case "mph": return "miles per hour"
        case "km/h": return "kilometers per hour"
        case "board", "boards": return one ? "board" : "boards"
        case "boards/s²": return "boards per second squared"
        default: return unit
        }
    }

    /// One metric tile as a sentence: "Entry Board, 17.3 boards, in the
    /// target range of 17 to 18". "--" means the metric couldn't be measured.
    static func metric(
        title: String,
        value: String,
        unit: String,
        numeric: Double? = nil,
        ideal: ClosedRange<Double>? = nil
    ) -> String {
        guard value != "--", !value.isEmpty else {
            return "\(title), not measured"
        }
        let number = numeric ?? Double(value)
        var parts = ["\(title), \(value) \(spokenUnit(unit, value: number))"]
        if let ideal {
            let range = "\(trim(ideal.lowerBound)) to \(trim(ideal.upperBound))"
            if let number, ideal.contains(number) {
                parts.append("in the target range of \(range)")
            } else {
                parts.append("target \(range)")
            }
        }
        return parts.joined(separator: ", ")
    }

    /// What the lane drawing shows, as one sentence. Each clause drops out
    /// when its number is missing, so a partly tracked throw still gets an
    /// honest summary instead of "nil".
    static func laneSummary(
        arrowBoard: Double?,
        breakpointBoard: Double?,
        breakpointFeet: Double?,
        entryBoard: Double?,
        entryAngle: Double?,
        isPocket: Bool
    ) -> String {
        var clauses: [String] = []
        if let arrowBoard {
            clauses.append("crosses the arrows on board \(one(arrowBoard))")
        }
        if let breakpointBoard {
            var bp = "breaks on board \(one(breakpointBoard))"
            if let breakpointFeet { bp += " at \(Int(breakpointFeet.rounded())) feet" }
            clauses.append(bp)
        }
        if let entryBoard {
            var entry = "enters on board \(one(entryBoard))"
            if let entryAngle { entry += " at \(one(entryAngle)) degrees" }
            if isPocket { entry += ", in the pocket" }
            clauses.append(entry)
        }
        guard !clauses.isEmpty else { return "Lane view. The ball's path wasn't tracked." }
        return "Lane view. The ball " + list(clauses) + "."
    }

    /// "a", "a and b", "a, b, and c".
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }

    private static func one(_ v: Double) -> String { String(format: "%.1f", v) }

    private static func trim(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
