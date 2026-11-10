import SwiftUI

/// Once-per-update notes for people who already used the app. Fresh installs
/// never see it: onboarding already covers everything, and "what's new" means
/// nothing to someone with no "before".
enum WhatsNew {
    /// The release these notes describe. Bump with new notes; a version with
    /// no notes shows nothing.
    static let notesVersion = "1.1"
    static let lastSeenVersionKey = "lastSeenVersion"

    /// 1.0 never wrote a last-seen version, so a missing value alone can't
    /// tell an upgrade from a fresh install. Someone who finished onboarding
    /// or has saved throws used an earlier version.
    static func shouldShow(lastSeenVersion: String?, hasUsedApp: Bool, currentVersion: String) -> Bool {
        guard currentVersion == notesVersion, lastSeenVersion != currentVersion else { return false }
        return lastSeenVersion != nil || hasUsedApp
    }

    struct Item: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    static let items: [Item] = [
        Item(
            symbol: "scope",
            title: "More accurate boards",
            detail: "Version 1.0 measured every throw a little to one side. That's fixed. Throws saved before this update are marked in History so you know which numbers to trust."
        ),
        Item(
            symbol: "arrow.down.to.line",
            title: "Tracking all the way to the pins",
            detail: "The ball is followed much farther down the lane, including on 60 fps recordings where it used to get lost partway."
        ),
        Item(
            symbol: "iphone.gen3.radiowaves.left.and.right",
            title: "Bumped phone check",
            detail: "Each throw is compared with your calibration. Small bumps are corrected for you, and if the phone moved a lot you'll be asked to recalibrate."
        ),
        Item(
            symbol: "gift",
            title: "25 free throws",
            detail: "Up from 10. Only throws that analyze successfully count."
        ),
    ]
}

struct WhatsNewView: View {
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("What's new in \(WhatsNew.notesVersion)")
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text("Thanks for using TrueLine.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)

                        ForEach(WhatsNew.items) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.symbol)
                                    .font(.title2)
                                    .foregroundStyle(Color.brandMint)
                                    .frame(width: 32)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                Button("Continue", action: onDone)
                    .buttonStyle(.primaryAction)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WhatsNewView {}
}
