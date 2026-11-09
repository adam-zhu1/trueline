import Testing
@testable import Trueline

@Suite("What's New gating")
struct WhatsNewTests {
    @Test func freshInstallSkipsTheNotes() {
        #expect(!WhatsNew.shouldShow(lastSeenVersion: nil, hasUsedApp: false, currentVersion: "1.1"))
    }

    /// 1.0 never stored a last-seen version; onboarding or saved throws are
    /// the evidence of an upgrade.
    @Test func upgradeFromOneZeroShowsOnce() {
        #expect(WhatsNew.shouldShow(lastSeenVersion: nil, hasUsedApp: true, currentVersion: "1.1"))
        #expect(!WhatsNew.shouldShow(lastSeenVersion: "1.1", hasUsedApp: true, currentVersion: "1.1"))
    }

    @Test func laterUpdatesNeedTheirOwnNotes() {
        #expect(!WhatsNew.shouldShow(lastSeenVersion: "1.1", hasUsedApp: true, currentVersion: "1.2"))
    }

    @Test func notesStayPlain() {
        for item in WhatsNew.items {
            #expect(!item.detail.contains("\u{2014}"), "no em dashes in \(item.title)")
        }
    }
}
