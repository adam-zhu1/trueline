import SwiftUI

/// Shown when analysis couldn't track the ball well enough to trust. Names
/// the reason for this throw (from the detector's gate counts) and points at
/// the fix that matches it: new corners when the lane outline is off, a new
/// recording otherwise.
struct TrackingFailedView: View {
    var failure: TrackingFailure
    /// Reassure free users the attempt cost them nothing. Only reliable
    /// results spend a free throw (TruelineStore.recordAnalyzedThrow).
    var showsFreeThrowNote: Bool
    var onAdjustCorners: () -> Void
    /// nil for imported clips: there's no camera to record with.
    var onRecordAgain: (() -> Void)?
    var onDiscard: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "eye.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandMint)
                    .accessibilityHidden(true)
                Text(failure.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if showsFreeThrowNote {
                    Text("This throw didn't use one of your free throws.")
                        .font(.footnote)
                        .foregroundStyle(Color.brandMint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Spacer()
                if failure.suggestsAdjustingCorners || onRecordAgain == nil {
                    adjustButton.buttonStyle(.primaryAction)
                    if let onRecordAgain { recordButton(onRecordAgain).buttonStyle(.secondaryAction) }
                } else if let onRecordAgain {
                    recordButton(onRecordAgain).buttonStyle(.primaryAction)
                    adjustButton.buttonStyle(.secondaryAction)
                }
                Button("Discard", role: .cancel) {
                    onDiscard()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
            }
            .foregroundStyle(.white)
            .padding()
        }
        .onAppear { appeared = true }
        .sensoryFeedback(.warning, trigger: appeared)
    }

    private var adjustButton: some View {
        Button {
            onAdjustCorners()
        } label: {
            Label("Adjust Corners", systemImage: "arrow.uturn.backward")
        }
    }

    private func recordButton(_ action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Label("Record Again", systemImage: "record.circle")
        }
    }
}

#Preview("Off lane") {
    TrackingFailedView(failure: .offLane, showsFreeThrowNote: true, onAdjustCorners: {}, onRecordAgain: {}, onDiscard: {})
}

#Preview("Lost early") {
    TrackingFailedView(failure: .lostEarly, showsFreeThrowNote: false, onAdjustCorners: {}, onRecordAgain: {}, onDiscard: {})
}
