import Foundation
import UIKit

/// When to ask for an App Store rating. Apple caps the system prompt at three
/// showings a year and may skip it anyway, so the app's own rule is about
/// timing: only after someone has seen a few real results, only on the way
/// back to Home (never mid-throw), and at most once per app version.
enum ReviewPrompt {
    /// Successful analyses before the first ask. One good result can be luck;
    /// three means the setup works for this person.
    static let minimumSuccessfulAnalyses = 3

    static let successfulAnalysesKey = "successfulAnalyses"
    static let lastPromptedVersionKey = "reviewPromptedVersion"

    static func shouldAsk(successfulAnalyses: Int, lastPromptedVersion: String?, currentVersion: String) -> Bool {
        successfulAnalyses >= minimumSuccessfulAnalyses && lastPromptedVersion != currentVersion
    }

    /// Counts every reliable result, unlocked or not. The free throw counter
    /// stops at the purchase, so it can't double as this.
    static func recordSuccessfulAnalysis(defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: successfulAnalysesKey) + 1, forKey: successfulAnalysesKey)
    }

    /// True when the caller should show the prompt now. Marks this version as
    /// asked, so a dismissed prompt doesn't come back until the next update.
    static func consumeIfDue(defaults: UserDefaults = .standard) -> Bool {
        let version = AppInfo.version
        guard shouldAsk(
            successfulAnalyses: defaults.integer(forKey: successfulAnalysesKey),
            lastPromptedVersion: defaults.string(forKey: lastPromptedVersionKey),
            currentVersion: version
        ) else { return false }
        defaults.set(version, forKey: lastPromptedVersionKey)
        return true
    }
}

/// App and device facts for the feedback row. Nothing personal: no name,
/// no identifiers, nothing from the shot history.
enum AppInfo {
    static let appStoreID = "6801953797"

    /// The App Store's write-a-review page. Allowed on a button at any time,
    /// unlike the system prompt.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    static let supportURL = URL(string: "https://adamzhu.dev/trueline/support")!

    /// TODO(Adam): a support address for the mail row. Until one exists the
    /// feedback row opens the support page and copies these details instead.
    static let feedbackEmail: String? = nil

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    /// Hardware identifier, e.g. "iPhone17,1". UIDevice.model only says "iPhone".
    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    @MainActor static var diagnostics: String {
        "TrueLine \(version) (\(build)), iOS \(UIDevice.current.systemVersion), \(deviceModel)"
    }

    @MainActor static var feedbackMailURL: URL? {
        guard let feedbackEmail else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "TrueLine feedback"),
            URLQueryItem(name: "body", value: "\n\n\(diagnostics)"),
        ]
        return components.url
    }
}
