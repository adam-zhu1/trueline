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
                        ForEach(groupedShots, id: \.title) { group in
                            Section(group.title) {
                                ForEach(group.shots) { shot in
                                    NavigationLink(value: shot.persistentModelID) {
                                        row(for: shot)
                                    }
                                }
                                .onDelete { offsets in
                                    for offset in offsets {
                                        modelContext.delete(group.shots[offset])
                                    }
                                }
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

    /// Shots grouped by session (newest session first); imported one-offs
    /// fall into a "Single shots" group.
    private var groupedShots: [(title: String, shots: [SavedShot])] {
        let bySession = Dictionary(grouping: shots) { $0.session?.persistentModelID }
        var groups: [(date: Date, title: String, shots: [SavedShot])] = []
        for (_, group) in bySession {
            if let session = group.first?.session {
                let title = "Session — \(session.date.formatted(date: .abbreviated, time: .shortened)) (\(group.count))"
                groups.append((session.date, title, group))
            } else {
                groups.append((group.first?.date ?? .distantPast, "Single shots", group))
            }
        }
        return groups.sorted { $0.date > $1.date }.map { ($0.title, $0.shots) }
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
                    MetricTile(title: "Entry Board", value: format(shot.entryBoard), unit: "board")
                    MetricTile(title: "Entry Angle", value: format(shot.entryAngleDegrees), unit: "°")
                    MetricTile(title: "Breakpoint", value: format(shot.breakpointBoard), unit: "board")
                    MetricTile(
                        title: "Breakpoint Distance",
                        value: shot.breakpointFeet.map { String(format: "%.0f", $0) } ?? "--",
                        unit: "ft"
                    )
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
