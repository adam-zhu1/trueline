import Foundation
import Testing
@testable import Trueline

@Suite("Review prompt timing")
struct ReviewPromptTests {
    @Test func waitsForThreeSuccessfulAnalyses() {
        #expect(!ReviewPrompt.shouldAsk(successfulAnalyses: 0, lastPromptedVersion: nil, currentVersion: "1.1"))
        #expect(!ReviewPrompt.shouldAsk(successfulAnalyses: 2, lastPromptedVersion: nil, currentVersion: "1.1"))
        #expect(ReviewPrompt.shouldAsk(successfulAnalyses: 3, lastPromptedVersion: nil, currentVersion: "1.1"))
    }

    @Test func asksOncePerVersion() {
        #expect(!ReviewPrompt.shouldAsk(successfulAnalyses: 9, lastPromptedVersion: "1.1", currentVersion: "1.1"))
        #expect(ReviewPrompt.shouldAsk(successfulAnalyses: 9, lastPromptedVersion: "1.0", currentVersion: "1.1"))
    }

    @Test func consumingMarksTheVersionAsked() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReviewPromptTests-\(UUID())"))
        for _ in 0..<3 { ReviewPrompt.recordSuccessfulAnalysis(defaults: defaults) }
        #expect(ReviewPrompt.consumeIfDue(defaults: defaults))
        #expect(!ReviewPrompt.consumeIfDue(defaults: defaults))
    }

    @Test func onlyAfterAResultWithHomeShowing() {
        #expect(ReviewPrompt.mayRequest(afterSuccessfulResult: true, captureOpen: false, somethingPresented: false))
        // A failed throw, a new capture, or a cover on top: not now.
        #expect(!ReviewPrompt.mayRequest(afterSuccessfulResult: false, captureOpen: false, somethingPresented: false))
        #expect(!ReviewPrompt.mayRequest(afterSuccessfulResult: true, captureOpen: true, somethingPresented: false))
        #expect(!ReviewPrompt.mayRequest(afterSuccessfulResult: true, captureOpen: false, somethingPresented: true))
    }

    @Test func writeReviewLinkTargetsTheApp() {
        let url = AppInfo.writeReviewURL.absoluteString
        #expect(url.contains("id6801953797"))
        #expect(url.hasSuffix("action=write-review"))
    }
}
