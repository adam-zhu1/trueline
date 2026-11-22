import Testing
@testable import Trueline

/// The analysis screen holds its finished result until the progress counter
/// reaches 100. Cancel during that hold used to swallow the cancellation and
/// spin forever on the main actor (or, late enough, still deliver the result
/// and spend a free throw).
@Suite("Analysis completion wait")
@MainActor
struct AnalysisWaitTests {
    @Test func returnsOnceTheCounterFinishes() async throws {
        var polls = 0
        try await AnalysisView.waitUntil(every: .milliseconds(1)) {
            polls += 1
            return polls >= 3
        }
        #expect(polls == 3)
    }

    @Test func cancellationEndsTheWaitWithAnError() async {
        let wait = Task { @MainActor in
            try await AnalysisView.waitUntil(every: .milliseconds(5)) { false }
        }
        try? await Task.sleep(for: .milliseconds(30))
        wait.cancel()
        let outcome = await wait.result
        #expect(throws: CancellationError.self) { try outcome.get() }
    }
}
