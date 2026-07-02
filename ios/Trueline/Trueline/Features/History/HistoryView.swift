import SwiftData
import SwiftUI

/// Past shots, newest first.
struct HistoryView: View {
    @Query(sort: \SavedShot.date, order: .reverse) private var shots: [SavedShot]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if shots.isEmpty {
                    ContentUnavailableView(
                        "No shots yet",
                        systemImage: "figure.bowling",
                        description: Text("Record or import a throw from the Bowl tab — saved shots show up here.")
                    )
                } else {
                    List {
                        ForEach(shots) { shot in
                            NavigationLink(value: shot.persistentModelID) {
                                row(for: shot)
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                modelContext.delete(shots[offset])
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let shot = modelContext.model(for: id) as? SavedShot {
                    ShotDetailView(shot: shot)
                }
            }
        }
    }

    private func row(for shot: SavedShot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shot.date, style: .time)
                    .font(.headline)
                Text(shot.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let speed = shot.speedMph {
                    Text("\(speed, specifier: "%.1f") mph")
                        .font(.subheadline.monospacedDigit())
                }
                if let arrows = shot.arrowBoard {
                    Text("arrows \(arrows, specifier: "%.1f")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// One shot's lane view and metrics.
struct ShotDetailView: View {
    let shot: SavedShot

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LaneViewCanvas(result: shot.laneViewResult)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Speed", value: format(shot.speedMph), unit: "mph")
                    MetricTile(title: "Board at Arrows", value: format(shot.arrowBoard), unit: "board")
                    MetricTile(title: "Breakpoint", value: format(shot.breakpointBoard), unit: "board")
                    MetricTile(title: "Entry Angle", value: format(shot.entryAngleDegrees), unit: "°")
                }
            }
            .padding()
        }
        .navigationTitle(shot.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedShot.self, inMemory: true)
}
