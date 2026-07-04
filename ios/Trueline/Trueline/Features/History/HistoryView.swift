import SwiftData
import SwiftUI

/// Past sessions (each opens its consistency summary), then imported one-off
/// shots. Newest first.
struct HistoryView: View {
    @Query(sort: \SavedShot.date, order: .reverse) private var shots: [SavedShot]
    @Query(sort: \BowlingSession.date, order: .reverse) private var sessions: [BowlingSession]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("speedUnit") private var speedUnit = "mph"

    /// A session row appears once it has a saved shot — the capture flow
    /// creates the session object before the first Save, so discard-only
    /// sessions exist but stay empty.
    private var activeSessions: [BowlingSession] {
        sessions.filter { !$0.shots.isEmpty }
    }

    private var singleShots: [SavedShot] {
        shots.filter { $0.session == nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeSessions.isEmpty && singleShots.isEmpty {
                    ContentUnavailableView(
                        "No shots yet",
                        systemImage: "figure.bowling",
                        description: Text("Record or import a throw from the Bowl tab — saved shots show up here.")
                    )
                } else {
                    List {
                        if !activeSessions.isEmpty {
                            Section("Sessions") {
                                ForEach(activeSessions) { session in
                                    NavigationLink(value: session.persistentModelID) {
                                        sessionRow(for: session)
                                    }
                                }
                                .onDelete { offsets in
                                    for offset in offsets {
                                        let session = activeSessions[offset]
                                        for shot in session.shots {
                                            ShotVideoStore.delete(name: shot.videoFileName)
                                            modelContext.delete(shot)
                                        }
                                        modelContext.delete(session)
                                    }
                                }
                            }
                        }
                        if !singleShots.isEmpty {
                            Section("Single shots") {
                                ForEach(singleShots) { shot in
                                    NavigationLink(value: shot.persistentModelID) {
                                        row(for: shot)
                                    }
                                }
                                .onDelete { offsets in
                                    for offset in offsets {
                                        let shot = singleShots[offset]
                                        ShotVideoStore.delete(name: shot.videoFileName)
                                        modelContext.delete(shot)
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
                } else if let session = modelContext.model(for: id) as? BowlingSession {
                    SessionDetailView(session: session)
                }
            }
        }
    }

    private func sessionRow(for session: BowlingSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date, style: .date)
                    .font(.headline)
                Text(session.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(session.shots.count) throw\(session.shots.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    Text("\(SpeedUnit.value(speed, unit: speedUnit), specifier: "%.1f") \(SpeedUnit.label(speedUnit))")
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

/// One saved shot, in the exact layout of the fresh Shot Result screen.
struct ShotDetailView: View {
    let shot: SavedShot

    var body: some View {
        ScrollView {
            ShotResultContent(
                result: shot.laneViewResult,
                clipURL: shot.videoWidth > 0 ? shot.videoURL : nil
            )
            .padding()
        }
        .navigationTitle(shot.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedShot.self, inMemory: true)
}
