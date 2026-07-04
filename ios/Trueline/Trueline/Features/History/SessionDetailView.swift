import SwiftData
import SwiftUI

/// One session, consistency first: mean ± spread across the session's throws
/// for the numbers a drill repeats (speed, arrows, entry board), then the
/// individual shots. Spread is the sample standard deviation.
struct SessionDetailView: View {
    let session: BowlingSession

    @Environment(\.modelContext) private var modelContext
    @AppStorage("speedUnit") private var speedUnit = "mph"

    private var shots: [SavedShot] {
        session.shots.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section("Consistency — \(shots.count) throws") {
                // Pros hold speed within 0.5 mph shot to shot — the one
                // spread with a published benchmark, so the one that earns
                // a mint tint when met. Both the values and the benchmark
                // convert together when the unit preference is km/h.
                consistencyRow(
                    title: "Speed", unit: SpeedUnit.label(speedUnit),
                    values: shots.compactMap { $0.speedMph.map { SpeedUnit.value($0, unit: speedUnit) } },
                    tightWithin: SpeedUnit.value(0.5, unit: speedUnit)
                )
                consistencyRow(title: "Board at Arrows", unit: "board", values: shots.compactMap(\.arrowBoard), tightWithin: nil)
                consistencyRow(title: "Entry Board", unit: "board", values: shots.compactMap(\.entryBoard), tightWithin: nil)
            }

            if let latest = shots.last {
                Section {
                    LaneViewCanvas(
                        result: latest.laneViewResult,
                        overlayPaths: shots.dropLast().map { shot in
                            zip(shot.pathBoards, shot.pathFeet).map { (board: $0, feet: $1) }
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Lines")
                } footer: {
                    if shots.count > 1 {
                        Text("All throws on one lane — brighter is more recent, the latest in full mint.")
                    }
                }
            }

            Section("Throws") {
                ForEach(Array(shots.enumerated()), id: \.element.persistentModelID) { index, shot in
                    NavigationLink(value: shot.persistentModelID) {
                        throwRow(number: index + 1, shot: shot)
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(shots[offset])
                    }
                }
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func consistencyRow(
        title: String, unit: String,
        values: [Double], tightWithin: Double?
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                // A metric can be missing on some throws (short track, no
                // speed window) — say so instead of silently averaging fewer.
                if !values.isEmpty, values.count < shots.count {
                    Text("\(values.count) of \(shots.count) throws")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statText(values: values, unit: unit, tightWithin: tightWithin)
        }
    }

    private func statText(values: [Double], unit: String, tightWithin: Double?) -> Text {
        guard !values.isEmpty else {
            return Text("--").foregroundStyle(.secondary)
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let meanText = Text(String(format: "%.1f", mean))
            .font(.body.monospacedDigit().bold())
        guard values.count >= 2 else {
            return meanText + Text(" \(unit)").font(.caption).foregroundStyle(.secondary)
        }
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        let sd = variance.squareRoot()
        let tight = tightWithin.map { sd <= $0 } ?? false
        let sdText = Text(String(format: " ± %.1f", sd))
            .font(.body.monospacedDigit())
            .foregroundStyle(tight ? Color.brandMint : Color.secondary)
        return meanText + sdText + Text(" \(unit)").font(.caption).foregroundStyle(.secondary)
    }

    private func throwRow(number: Int, shot: SavedShot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Throw \(number)")
                    .font(.headline)
                Text(shot.date, style: .time)
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
