import SwiftUI

/// Stand-in for the top-down lane view + ball path. Replaced with the real
/// visualization once the metrics pipeline is ported to Swift.
struct LaneViewPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.85))
            Text("[ top-down lane view + ball path ]")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    LaneViewPlaceholder()
        .frame(height: 240)
        .padding()
}
