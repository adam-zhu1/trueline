import Testing
@testable import Trueline

@Suite("Free throw quota and restore")
struct StoreQuotaTests {
    @Test("used count stays inside 0...limit")
    func usedIsClamped() {
        let limit = TruelineStore.freeThrowLimit
        #expect(TruelineStore.clampedUsed(-74) == 0)
        #expect(TruelineStore.clampedUsed(3) == 3)
        #expect(TruelineStore.clampedUsed(limit + 9) == limit)
    }

    @Test("banking more than the limit leaves exactly the limit")
    func bankIsCapped() {
        let limit = TruelineStore.freeThrowLimit
        #expect(TruelineStore.usedAfterBanking(99) == 0)
        #expect(TruelineStore.usedAfterBanking(limit) == 0)
        #expect(TruelineStore.usedAfterBanking(10) == limit - 10)
    }

    @Test("restore outcome: a found purchase wins, a failed sync says so")
    func restoreOutcome() {
        #expect(RestoreOutcome(unlocked: true, syncFailed: false) == .unlocked)
        #expect(RestoreOutcome(unlocked: true, syncFailed: true) == .unlocked)
        #expect(RestoreOutcome(unlocked: false, syncFailed: false) == .nothingToRestore)
        #expect(RestoreOutcome(unlocked: false, syncFailed: true) == .couldNotConnect)
        #expect(RestoreOutcome.nothingToRestore.title == "No purchase to restore")
        for outcome in [RestoreOutcome.unlocked, .nothingToRestore, .couldNotConnect] {
            #expect(!outcome.title.contains("\u{2014}"))
            #expect(!outcome.message.contains("\u{2014}"))
        }
    }
}
