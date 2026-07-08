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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(.white.opacity(0.12), in: Circle())
                            .foregroundStyle(.white)
                    }
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
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        buy()
                    } label: {
                        if store.purchasing {
                            ProgressView().tint(.black)
                        } else {
                            Text("Unlock TrueLine — \(price)")
                        }
                    }
                    .buttonStyle(.primaryAction)
                    .disabled(store.purchasing)

                    Text("One-time purchase. Yours forever.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.brandMint)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { onDone() }
        }
        .alert("Purchase didn't go through", isPresented: $purchaseFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nothing was charged. Check your connection and try again.")
        }
    }

    private var subtitle: String {
        if store.freeThrowsLeft == 0 {
            "You've used all \(TruelineStore.freeThrowLimit) free throws. Unlock once and keep the numbers coming."
        } else {
            "The numbers a coach would give you, on every throw you ever bowl."
        }
    }

    /// Fallback covers the moment before the product loads (or the App Store
    /// being unreachable) — the button still reads right, and StoreKit
    /// enforces the real price at purchase time.
    private var price: String {
        store.product?.displayPrice ?? "$14.99"
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

    private func buy() {
        Task {
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
