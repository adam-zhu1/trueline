import SwiftUI

/// Past shots. Backed by mock data until persistence lands.
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            List(Shot.sampleData) { shot in
                NavigationLink(value: shot) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shot.date, style: .time)
                                .font(.headline)
                            Text(shot.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(shot.speedMph, specifier: "%.1f") mph")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Shot.self) { shot in
                ShotDetailView(shot: shot)
            }
        }
    }
}

/// One shot's lane view and metrics.
struct ShotDetailView: View {
    let shot: Shot

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LaneViewPlaceholder()
                    .frame(height: 280)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Speed", value: String(format: "%.1f", shot.speedMph), unit: "mph")
                    MetricTile(title: "Board at Arrows", value: String(format: "%.1f", shot.boardAtArrows), unit: "board")
                    MetricTile(title: "Breakpoint", value: String(format: "%.1f", shot.breakpointBoard), unit: "board")
                    MetricTile(title: "Entry Angle", value: String(format: "%.1f", shot.entryAngleDegrees), unit: "°")
                }
            }
            .padding()
        }
        .navigationTitle(shot.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
}
