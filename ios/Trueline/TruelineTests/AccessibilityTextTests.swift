import Testing
@testable import Trueline

@Suite("VoiceOver text")
struct AccessibilityTextTests {
    @Test("Metric tiles read as one sentence with a spoken unit")
    func metricSentence() {
        #expect(
            AccessibilityText.metric(title: "Speed", value: "17.2", unit: "mph")
                == "Speed, 17.2 miles per hour"
        )
        #expect(
            AccessibilityText.metric(title: "Breakpoint Distance", value: "42", unit: "ft")
                == "Breakpoint Distance, 42 feet"
        )
        #expect(
            AccessibilityText.metric(title: "Hook Factor", value: "3.1", unit: "boards/s²")
                == "Hook Factor, 3.1 boards per second squared"
        )
    }

    @Test("Target ranges say whether the throw is inside")
    func targetRange() {
        #expect(
            AccessibilityText.metric(title: "Entry Angle", value: "5.2", unit: "°", numeric: 5.2, ideal: 4...6)
                == "Entry Angle, 5.2 degrees, in the target range of 4 to 6"
        )
        #expect(
            AccessibilityText.metric(title: "Entry Angle", value: "8.3", unit: "°", numeric: 8.3, ideal: 4...6)
                == "Entry Angle, 8.3 degrees, target 4 to 6"
        )
        #expect(
            AccessibilityText.metric(title: "Entry Board", value: "17.3", unit: "board", numeric: 17.3, ideal: 16.5...18.5)
                == "Entry Board, 17.3 boards, in the target range of 16.5 to 18.5"
        )
    }

    @Test("Singular units and unmeasured metrics")
    func singularAndMissing() {
        #expect(AccessibilityText.metric(title: "Hook", value: "1.0", unit: "boards") == "Hook, 1.0 board")
        #expect(AccessibilityText.metric(title: "Speed", value: "--", unit: "mph") == "Speed, not measured")
    }

    @Test("Lane summary covers the whole path")
    func fullLaneSummary() {
        let text = AccessibilityText.laneSummary(
            arrowBoard: 12, breakpointBoard: 7, breakpointFeet: 41.6,
            entryBoard: 17.4, entryAngle: 5.1, isPocket: true
        )
        #expect(text == "Lane view. The ball crosses the arrows on board 12.0, breaks on board 7.0 at 42 feet, and enters on board 17.4 at 5.1 degrees, in the pocket.")
    }

    @Test("Lane summary drops what wasn't tracked")
    func partialLaneSummary() {
        #expect(
            AccessibilityText.laneSummary(
                arrowBoard: 12, breakpointBoard: nil, breakpointFeet: nil,
                entryBoard: nil, entryAngle: nil, isPocket: false
            ) == "Lane view. The ball crosses the arrows on board 12.0."
        )
        #expect(
            AccessibilityText.laneSummary(
                arrowBoard: nil, breakpointBoard: nil, breakpointFeet: nil,
                entryBoard: nil, entryAngle: nil, isPocket: false
            ) == "Lane view. The ball's path wasn't tracked."
        )
    }

    @Test("Lists join the way people say them")
    func lists() {
        #expect(AccessibilityText.list(["a"]) == "a")
        #expect(AccessibilityText.list(["a", "b"]) == "a and b")
        #expect(AccessibilityText.list(["a", "b", "c"]) == "a, b, and c")
    }
}
