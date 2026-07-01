import SwiftUI

/// The primary tab: an entry point that launches the capture flow.
struct BowlHomeView: View {
    @State private var showCapture = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.bowling")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("Trueline")
                    .font(.largeTitle.bold())
                Text("Record a throw to get your line, speed, breakpoint, and entry angle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    showCapture = true
                } label: {
                    Label("Start Session", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Bowl")
            .fullScreenCover(isPresented: $showCapture) {
                CaptureFlowView()
            }
        }
    }
}

#Preview {
    BowlHomeView()
}
