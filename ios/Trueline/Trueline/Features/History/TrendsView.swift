import Charts
import SwiftData
import SwiftUI

/// Session-over-session trends: one small chart per metric — never combined,
/// the scales differ — plus per-ball averages when sessions are tagged. All
/// computed from saved shots; nothing here touches the analyzer.
struct TrendsView: View {
    let sessions: [BowlingSession]

    @AppStorage("speedUnit") private var speedUnit = "mph"

    private struct Point: Identifiable {
        var id: Int { index }
        let index: Int
        let value: Double
    }

    /// Sessions with shots, oldest first — chart x is the session number.
    private var ordered: [BowlingSession] {
        sessions.filter { !$0.shots.isEmpty }.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            chartSection("Speed", unit: SpeedUnit.label(speedUnit)) { shots in
                average(shots.compactMap { $0.speedMph.map { SpeedUnit.value($0, unit: speedUnit) } })
            }
            chartSection("Pocket Hits", unit: "%", domain: 0...100) { shots in
                let entries = shots.filter { $0.entryBoard != nil }
                guard !entries.isEmpty else { return nil }
                return Double(entries.filter(\.isPocketHit).count) / Double(entries.count) * 100
            }
            chartSection("Hook", unit: "boards") { average($0.compactMap(\.hookBoards)) }
            chartSection("Entry Angle", unit: "°", idealBand: 4...6) {
                average($0.compactMap(\.entryAngleDegrees))
            }
            ballSection
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Per-session charts

    private func chartSection(
        _ title: String, unit: String,
        idealBand: ClosedRange<Double>? = nil,
        domain: ClosedRange<Double>? = nil,
        value: ([SavedShot]) -> Double?
    ) -> some View {
        let points = ordered.enumerated().compactMap { index, session in
            value(session.shots).map { Point(index: index, value: $0) }
        }
        return Section("\(title) — session average (\(unit))") {
            if points.count >= 2 {
                chart(points: points, idealBand: idealBand, domain: domain)
                    .listRowBackground(Color.clear)
            } else {
                Text("Bowl two sessions with this metric to see a trend.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chart(
        points: [Point], idealBand: ClosedRange<Double>?, domain: ClosedRange<Double>?
    ) -> some View {
        let base = Chart {
            // Coaching band (entry angle 4–6°): context, drawn under the data.
            if let idealBand {
                RectangleMark(
                    yStart: .value("Ideal", idealBand.lowerBound),
                    yEnd: .value("Ideal", idealBand.upperBound)
                )
                .foregroundStyle(Color.brandMint.opacity(0.08))
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Session", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.brandMint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Session", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.brandMint)
                .symbolSize(50)
            }
            // Label only the latest point — the number that answers "where am
            // I now"; the line carries the rest.
            if let last = points.last {
                PointMark(
                    x: .value("Session", last.index),
                    y: .value("Value", last.value)
                )
                .symbolSize(0)
                .annotation(position: .top, spacing: 6) {
                    Text(String(format: "%.1f", last.value))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(Color.brandMint)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: labelIndices) { mark in
                AxisValueLabel {
                    if let index = mark.as(Int.self), ordered.indices.contains(index) {
                        Text(ordered[index].date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
            }
        }
        // Half-a-slot margin keeps end points (and the latest-value label)
        // off the plot edges.
        .chartXScale(domain: -0.5...(Double(ordered.count - 1) + 0.5))
        .frame(height: 150)
        .padding(.vertical, 8)

        return Group {
            if let domain {
                base.chartYScale(domain: domain)
            } else {
                // No zero baseline: a line encodes position, not length, and
                // session averages vary in a narrow band — anchoring at zero
                // flattens the trend into a sliver.
                base.chartYScale(domain: .automatic(includesZero: false))
            }
        }
    }

    /// Every session when they fit; otherwise a thinned subset so date labels
    /// don't collide.
    private var labelIndices: [Int] {
        let count = ordered.count
        guard count > 6 else { return Array(0..<count) }
        let step = Int((Double(count) / 6.0).rounded(.up))
        var indices = Array(stride(from: 0, to: count, by: step))
        if indices.last != count - 1 { indices.append(count - 1) }
        return indices
    }

    // MARK: Per-ball comparison

    @ViewBuilder
    private var ballSection: some View {
        let groups = Dictionary(grouping: ordered.filter { !$0.ball.isEmpty }, by: \.ball)
        if !groups.isEmpty {
            Section {
                ForEach(groups.keys.sorted(), id: \.self) { ball in
                    ballRow(ball: ball, sessions: groups[ball] ?? [])
                }
            } header: {
                Text("By Ball")
            } footer: {
                Text("Averages across every session tagged with that ball — tag sessions to compare equipment.")
            }
        }
    }

    private func ballRow(ball: String, sessions: [BowlingSession]) -> some View {
        let shots = sessions.flatMap(\.shots)
        let speed = average(shots.compactMap { $0.speedMph.map { SpeedUnit.value($0, unit: speedUnit) } })
        let hook = average(shots.compactMap(\.hookBoards))
        let entries = shots.filter { $0.entryBoard != nil }
        let pocket: Double? = entries.isEmpty
            ? nil
            : Double(entries.filter(\.isPocketHit).count) / Double(entries.count) * 100
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ball).font(.headline)
                Spacer()
                Text("\(shots.count) throw\(shots.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                stat(speed, format: "%.1f", label: SpeedUnit.label(speedUnit))
                stat(hook, format: "%.1f", label: "boards hook")
                stat(pocket, format: "%.0f%%", label: "pocket")
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stat(_ value: Double?, format: String, label: String) -> some View {
        if let value {
            (Text(String(format: format, value))
                .font(.subheadline.monospacedDigit().bold())
                + Text(" \(label)").font(.caption2).foregroundStyle(Color.secondary))
        }
    }

    private func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
