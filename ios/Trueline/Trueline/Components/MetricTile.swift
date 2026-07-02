import SwiftUI

/// A single labelled metric (e.g. "Speed — 17.2 mph"). Reused on the results and
/// shot-detail screens. Tiles with an ideal range show it as a caption and tint
/// the value mint when the shot lands inside — a nudge, not a judgment, so
/// out-of-range values stay neutral.
struct MetricTile: View {
    var title: String
    var value: String
    var unit: String
    var numeric: Double?
    var ideal: ClosedRange<Double>?

    private var inIdeal: Bool {
        guard let numeric, let ideal else { return false }
        return ideal.contains(numeric)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title.bold())
                    .foregroundStyle(inIdeal ? Color.brandMint : Color.primary)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let ideal {
                Text("target \(rangeText(ideal))")
                    .font(.caption2)
                    .foregroundStyle(inIdeal ? Color.brandMint.opacity(0.8) : Color.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func rangeText(_ range: ClosedRange<Double>) -> String {
        func fmt(_ v: Double) -> String {
            v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
        }
        return "\(fmt(range.lowerBound))–\(fmt(range.upperBound))"
    }
}

#Preview {
    VStack {
        MetricTile(title: "Speed", value: "17.2", unit: "mph")
        MetricTile(title: "Entry Board", value: "17.3", unit: "board", numeric: 17.3, ideal: 17...18)
        MetricTile(title: "Entry Angle", value: "8.3", unit: "°", numeric: 8.3, ideal: 4...6)
    }
    .padding()
}
