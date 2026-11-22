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
    nonisolated static let freeThrowLimit = 25

    private(set) var isUnlocked: Bool
    private(set) var product: Product?
    private(set) var purchasing = false
    /// True while Restore Purchases is talking to the App Store.
    private(set) var restoring = false

    /// Successful analyses consumed. Calibration throws and failed detections
    /// never call `recordAnalyzedThrow`, so they don't burn quota — someone
    /// should hit the gate having seen 25 real results, not fewer.
    private(set) var freeThrowsUsed: Int {
        didSet { UserDefaults.standard.set(freeThrowsUsed, forKey: "freeThrowsUsed") }
    }

    var freeThrowsLeft: Int { Self.freeThrowLimit - Self.clampedUsed(freeThrowsUsed) }
    var canAnalyze: Bool { isUnlocked || freeThrowsLeft > 0 }

    private var updatesTask: Task<Void, Never>?

    init() {
        // `-freeThrowsUsed <n>` (DEBUG launch arg) lands here too: the
        // argument domain shadows the persistent one in UserDefaults.
        freeThrowsUsed = Self.clampedUsed(UserDefaults.standard.integer(forKey: "freeThrowsUsed"))
        // `-bankFreeThrows <n>` (launch arg, positive value — argument-domain
        // parsing drops dash-prefixed values): field-test insurance. Persists
        // immediately so every later normal launch keeps the bank. Requires a
        // paired Mac to trigger; App Store launches can't pass arguments.
        let bank = UserDefaults.standard.integer(forKey: "bankFreeThrows")
        if bank > 0 {
            let banked = Self.usedAfterBanking(bank)
            freeThrowsUsed = banked
            // didSet doesn't fire in init — persist by hand.
            UserDefaults.standard.set(banked, forKey: "freeThrowsUsed")
        }
        isUnlocked = UserDefaults.standard.bool(forKey: "unlimitedUnlocked")
        #if DEBUG
        // `-unlockAll` — field-test a build without the gate in the way.
        if UserDefaults.standard.bool(forKey: "unlockAll") { isUnlocked = true }
        #endif
    }

    /// Keeps the used count inside 0...limit whatever was stored or passed
    /// as a launch argument, so the app never reads "99 of 25 left".
    nonisolated static func clampedUsed(_ used: Int) -> Int {
        min(max(used, 0), freeThrowLimit)
    }

    /// Used count after `-bankFreeThrows <bank>`: the bank is how many free
    /// throws are left, capped at the limit.
    nonisolated static func usedAfterBanking(_ bank: Int) -> Int {
        clampedUsed(freeThrowLimit - bank)
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
        await loadProduct()
    }

    /// True once a product request has come back empty or failed, so the
    /// paywall can say the App Store is unreachable instead of guessing a
    /// price.
    private(set) var productUnavailable = false

    /// Loads the product if it isn't loaded yet. The paywall calls this on
    /// appear, so an offline launch recovers once the connection is back.
    func loadProduct() async {
        guard product == nil else { return }
        productUnavailable = false   // the paywall shows a spinner meanwhile
        product = try? await Product.products(for: [Self.productID]).first
        productUnavailable = product == nil
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
    /// restores silently. Returns what to tell the user; nil when they
    /// cancelled the App Store sign-in.
    func restore() async -> RestoreOutcome? {
        restoring = true
        defer { restoring = false }
        var syncFailed = false
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return nil
        } catch {
            syncFailed = true
        }
        await refreshEntitlements()
        return RestoreOutcome(unlocked: isUnlocked, syncFailed: syncFailed)
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
        freeThrowsUsed = Self.clampedUsed(freeThrowsUsed + 1)
    }

    #if DEBUG
    /// Settings → Debug: replay the out-of-throws moment on demand.
    func resetFreeThrows() {
        freeThrowsUsed = 0
    }
    #endif
}

/// What Restore Purchases found, with the plain alert copy for it.
enum RestoreOutcome: Equatable {
    case unlocked
    case nothingToRestore
    case couldNotConnect

    /// The entitlement wins: a cached purchase still counts as restored
    /// even when the sync itself failed.
    init(unlocked: Bool, syncFailed: Bool) {
        self = unlocked ? .unlocked : (syncFailed ? .couldNotConnect : .nothingToRestore)
    }

    var title: String {
        switch self {
        case .unlocked: "Purchase restored"
        case .nothingToRestore: "No purchase to restore"
        case .couldNotConnect: "Couldn't reach the App Store"
        }
    }

    var message: String {
        switch self {
        case .unlocked: "TrueLine Unlimited is unlocked on this iPhone."
        case .nothingToRestore: "This Apple Account hasn't bought TrueLine Unlimited."
        case .couldNotConnect: "Nothing was restored. Check your connection and try again."
        }
    }
}
