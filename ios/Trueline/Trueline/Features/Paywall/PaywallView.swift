import StoreKit
import SwiftUI

/// The purchase screen for TrueLine Unlimited — shown when the free throws
/// run out (home gate, mid-session gate) and from Settings. One-time
/// purchase, so the pitch is simple: keep every number, forever.
struct PaywallView: View {
    @Environment(TruelineStore.self) private var store
    /// Called when the user leaves — after unlocking or by dismissing.
    var onDone: () -> Void

    @State private var purchaseFailed = false
    @State private var restoreOutcome: RestoreOutcome?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // At the accessibility text sizes the pitch outgrows the screen;
            // scroll then rather than clip the buy button.
            if typeSize.isAccessibilitySize {
                ScrollView { layout }
            } else {
                layout
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { onDone() }
        }
        .task { await store.loadProduct() }
        .alert("Purchase didn't go through", isPresented: $purchaseFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nothing was charged. Check your connection and try again.")
        }
        .alert(
            restoreOutcome?.title ?? "",
            isPresented: Binding(get: { restoreOutcome != nil }, set: { if !$0 { restoreOutcome = nil } }),
            presenting: restoreOutcome
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { outcome in
            Text(outcome.message)
        }
    }

    private var layout: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal)

            Spacer()

            OnboardingArtView(art: .metrics)

            Text("Every throw, measured.\nNo limits.")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                row("Unlimited analyzed throws")
                row("Speed, breakpoint, and entry angle on every shot")
                row("Session history and consistency, forever")
            }
            .accessibilityElement(children: .combine)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    buy()
                } label: {
                    if store.purchasing || (store.product == nil && !store.productUnavailable) {
                        ProgressView().tint(.black)
                    } else if let price = store.product?.displayPrice {
                        Text("Unlock TrueLine for \(price)")
                    } else {
                        Text("Try Again")
                    }
                }
                .buttonStyle(.primaryAction)
                .disabled(store.purchasing || (store.product == nil && !store.productUnavailable))

                if store.product == nil && store.productUnavailable {
                    Text("Couldn't reach the App Store. Check your connection and try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("One-time purchase. Yours forever.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    restore()
                } label: {
                    if store.restoring {
                        HStack(spacing: 8) {
                            ProgressView().tint(Color.brandMint)
                            Text("Restoring…")
                        }
                    } else {
                        Text("Restore Purchases")
                    }
                }
                .buttonStyle(.textAction)
                .disabled(store.restoring || store.purchasing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var subtitle: String {
        if store.freeThrowsLeft == 0 {
            "You've used all \(TruelineStore.freeThrowLimit) free throws. Unlock once and keep the numbers coming."
        } else {
            "The numbers a coach would give you, on every throw you ever bowl."
        }
    }

    private func row(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.brandMint)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    /// A found purchase closes the paywall through the isUnlocked onChange;
    /// anything else gets a plain alert so the tap never looks ignored.
    private func restore() {
        Task {
            guard let outcome = await store.restore(), outcome != .unlocked else { return }
            restoreOutcome = outcome
        }
    }

    private func buy() {
        Task {
            // No product means the App Store didn't answer; the button reads
            // Try Again and reloads instead of guessing a price.
            if store.product == nil {
                await store.loadProduct()
                return
            }
            do {
                // Success closes via the isUnlocked onChange; cancel/pending
                // just leaves the paywall up.
                _ = try await store.purchase()
            } catch {
                purchaseFailed = true
            }
        }
    }
}

#Preview {
    PaywallView {}
        .environment(TruelineStore())
}
