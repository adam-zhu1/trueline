import SwiftUI

/// Shown when analysis couldn't track the ball well enough to trust.
struct TrackingFailedView: View {
    var onAdjustCorners: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "eye.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandMint)
                Text("Couldn't track the ball")
                    .font(.title3.bold())
                Text("Common causes: the corners don't match the lane, the throw isn't fully visible, or the lighting is very dim. Adjust the corners and try again, or record a new throw.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
                Button {
                    onAdjustCorners()
                } label: {
                    Label("Adjust Corners", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.primaryAction)
                Button("Discard", role: .cancel) {
                    onDiscard()
                }
                .buttonStyle(.secondaryAction)
            }
            .foregroundStyle(.white)
            .padding()
        }
    }
}

#Preview {
    TrackingFailedView(onAdjustCorners: {}, onDiscard: {})
}
