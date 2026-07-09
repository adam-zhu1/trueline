import Foundation
import StoreKit

/// Purchase state + the free-throw quota, as one object: every gate in the app
/// asks the same question ("can this user analyze another throw?") so the
/// answer lives in one place.
///
/// TrueLine Unlimited is a single non-consumable — no subscriptions, no
/// server. Entitlement comes from StoreKit 2's local transaction cache
/// (works offline) and is mirrored into UserDefaults only so a cold launch
/// doesn't flash the gate while StoreKit warms up.
@MainActor
@Observable
final class TruelineStore {
    static let productID = "com.adamzhu.Trueline.unlimited"
    static let freeThrowLimit = 10

    private(set) var isUnlocked: Bool
    private(set) var product: Product?
    private(set) var purchasing = false

    /// Successful analyses consumed. Calibration throws and failed detections
    /// never call `recordAnalyzedThrow`, so they don't burn quota — someone
    /// should hit the gate having seen 10 real results, not 6.
    private(set) var freeThrowsUsed: Int {
        didSet { UserDefaults.standard.set(freeThrowsUsed, forKey: "freeThrowsUsed") }
    }

    var freeThrowsLeft: Int { max(0, Self.freeThrowLimit - freeThrowsUsed) }
    var canAnalyze: Bool { isUnlocked || freeThrowsLeft > 0 }

    private var updatesTask: Task<Void, Never>?

    init() {
        // `-freeThrowsUsed <n>` (DEBUG launch arg) lands here too: the
        // argument domain shadows the persistent one in UserDefaults.
        freeThrowsUsed = UserDefaults.standard.integer(forKey: "freeThrowsUsed")
        isUnlocked = UserDefaults.standard.bool(forKey: "unlimitedUnlocked")
        #if DEBUG
        // `-unlockAll` — field-test a build without the gate in the way.
        if UserDefaults.standard.bool(forKey: "unlockAll") { isUnlocked = true }
        #endif
    }

    /// Call once at launch: syncs the entitlement, loads the product for its
    /// localized price, and keeps listening for out-of-band transactions
    /// (Ask to Buy approvals, purchases on another device, refunds).
    func start() async {
        // Scene re-creation can call this again — don't stack listeners.
        updatesTask?.cancel()
        updatesTask = Task {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update,
                   transaction.productID == Self.productID {
                    await transaction.finish()
                }
                refreshEntitlement(from: update)
            }
        }
        await refreshEntitlements()
        product = try? await Product.products(for: [Self.productID]).first
    }

    /// True on a finished purchase; false when the user cancelled or the
    /// purchase went pending (Ask to Buy — unlocks later via the updates
    /// stream). Throws on real failures so the paywall can show an error.
    func purchase() async throws -> Bool {
        guard let product else {
            throw StoreKitError.notAvailableInStorefront
        }
        purchasing = true
        defer { purchasing = false }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            setUnlocked(true)
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// "Restore Purchases": re-sync with the App Store, then re-derive the
    /// entitlement. Required by App Review even though StoreKit 2 usually
    /// restores silently.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setUnlocked(unlocked)
    }

    private func refreshEntitlement(from update: VerificationResult<Transaction>) {
        guard case .verified(let transaction) = update,
              transaction.productID == Self.productID else { return }
        setUnlocked(transaction.revocationDate == nil)
    }

    private func setUnlocked(_ value: Bool) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "unlockAll") { return }
        #endif
        isUnlocked = value
        UserDefaults.standard.set(value, forKey: "unlimitedUnlocked")
    }

    /// Count a throw against the quota — call only when an analysis produced
    /// reliable metrics.
    func recordAnalyzedThrow() {
        guard !isUnlocked else { return }
        freeThrowsUsed += 1
    }

    #if DEBUG
    /// Settings → Debug: replay the out-of-throws moment on demand.
    func resetFreeThrows() {
        freeThrowsUsed = 0
    }
    #endif
}
