import Charts
import SwiftData
import SwiftUI

/// The Stats tab: an all-time dashboard over every saved shot — hero totals,
/// average tiles, where shots enter the pins, per-ball comparison bars, and
/// session-over-session trend lines. All derived from saved shots; nothing
/// here touches the analyzer. Every mark is brand mint (single series —
/// identity comes from each card's title, not a legend).
struct StatsView: View {
    @Query(sort: \SavedShot.date) private var shots: [SavedShot]
    @Query(sort: \BowlingSession.date) private var sessions: [BowlingSession]

    @AppStorage("speedUnit") private var speedUnit = "mph"

    private struct Point: Identifiable {
        var id: Int { index }
        let index: Int
        let value: Double
    }

    /// Sessions with shots, oldest first — trend x is the session number.
    private var ordered: [BowlingSession] {
        sessions.filter { !$0.shots.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if shots.isEmpty {
                    ContentUnavailableView(
                        "No stats yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Record or import a throw from the Bowl tab — every saved shot builds your stats.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            hero
                            averageTiles
                            entryBoardCard
                            ballCard
                            Text("Trends")
                                .font(.title3.bold())
                                .padding(.top, 6)
                            trendCard("Speed", unit: SpeedUnit.label(speedUnit)) { shots in
                                average(shots.compactMap { $0.speedMph.map { SpeedUnit.value($0, unit: speedUnit) } })
                            }
                            trendCard("Pocket Hits", unit: "%", domain: 0...100) { shots in
                                pocketPercent(of: shots)
                            }
                            trendCard("Hook", unit: "boards") { average($0.compactMap(\.hookBoards)) }
                            trendCard("Entry Angle", unit: "°", idealBand: 4...6) {
                                average($0.compactMap(\.entryAngleDegrees))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: All-time hero + tiles

    private var hero: some View {
        let activeDays = Set(shots.map { Calendar.current.startOfDay(for: $0.date) }).count
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(shots.count)")
                .font(.system(size: 54, weight: .bold))
                .monospacedDigit()
            Text("throws measured")
                .font(.headline)
                .foregroundStyle(Color.brandMint)
            Text("\(ordered.count) session\(ordered.count == 1 ? "" : "s") · \(activeDays) day\(activeDays == 1 ? "" : "s") bowled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var averageTiles: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            averageTile(
                "Avg Speed",
                value: format(average(shots.compactMap { $0.speedMph.map { SpeedUnit.value($0, unit: speedUnit) } })),
                unit: SpeedUnit.label(speedUnit)
            )
            averageTile("Avg Hook", value: format(average(shots.compactMap(\.hookBoards))), unit: "boards")
            averageTile(
                "Pocket",
                value: pocketPercent(of: shots).map { String(format: "%.0f", $0) } ?? "--",
                unit: "%"
            )
        }
    }

    /// MetricTile's layout at a third of the width — smaller value type so
    /// three digits and a unit never wrap.
    private func averageTile(_ title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.monospacedDigit().bold())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Entry-board distribution

    /// Shots per board at the pins — the spread a bowler feels but never
    /// sees. The mint band marks the pocket.
    private var entryBoardCard: some View {
        let boards = shots.compactMap { $0.entryBoard.map { $0.rounded() } }
        let counts = Dictionary(grouping: boards, by: { $0 }).mapValues(\.count)
        let lo = max(1, (boards.min() ?? 10) - 2)
        let hi = min(39, (boards.max() ?? 25) + 2)
        return card("Where Shots Enter", footer: "Boards \(Int(ShotResult.pocketBoards.lowerBound))–\(Int(ShotResult.pocketBoards.upperBound)) are the pocket.") {
            if counts.isEmpty {
                Text("No entry boards tracked yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    RectangleMark(
                        xStart: .value("Pocket", ShotResult.pocketBoards.lowerBound - 0.5),
                        xEnd: .value("Pocket", ShotResult.pocketBoards.upperBound + 0.5)
                    )
                    .foregroundStyle(Color.brandMint.opacity(0.12))
                    ForEach(counts.keys.sorted(), id: \.self) { board in
                        BarMark(
                            x: .value("Board", board),
                            y: .value("Shots", counts[board] ?? 0),
                            // Fixed width: .ratio() needs a categorical axis
                            // to size against and renders nothing on this
                            // continuous board scale.
                            width: .fixed(14)
                        )
                        .foregroundStyle(Color.brandMint)
                        .cornerRadius(2)
                    }
                }
                .chartXScale(domain: lo - 0.5...hi + 0.5)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 140)
            }
        }
    }

    // MARK: Per-ball comparison

    private var ballCard: some View {
        let groups = Dictionary(
            grouping: shots.filter { !$0.effectiveBall.isEmpty },
            by: \.effectiveBall
        )
        let balls = groups.keys.sorted()
        return card(
            "By Ball",
            footer: balls.isEmpty
                ? "Tag shots with a ball on the results screen to compare equipment."
                : balls.map { "\($0) — \(groups[$0]?.count ?? 0) throws" }.joined(separator: " · ")
        ) {
            if !balls.isEmpty {
                ballBars("Pocket %", balls: balls, labelFormat: "%.0f%%") {
                    pocketPercent(of: groups[$0] ?? [])
                }
                ballBars("Avg Hook (boards)", balls: balls, labelFormat: "%.1f") {
                    average((groups[$0] ?? []).compactMap(\.hookBoards))
                }
            }
        }
    }

    /// One horizontal bar per ball, value labeled at the bar's end — few
    /// categories, so direct labels beat an axis.
    private func ballBars(
        _ title: String, balls: [String], labelFormat: String,
        value: @escaping (String) -> Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(balls, id: \.self) { ball in
                    if let v = value(ball) {
                        BarMark(
                            x: .value(title, v),
                            y: .value("Ball", ball),
                            height: .fixed(14)
                        )
                        .foregroundStyle(Color.brandMint)
                        .cornerRadius(3)
                        .annotation(position: .trailing, spacing: 6) {
                            Text(String(format: labelFormat, v))
                                .font(.caption2.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { mark in
                    AxisValueLabel()
                }
            }
            .frame(height: CGFloat(balls.count) * 34 + 8)
        }
    }

    // MARK: Session trends

    private func trendCard(
        _ title: String, unit: String,
        idealBand: ClosedRange<Double>? = nil,
        domain: ClosedRange<Double>? = nil,
        value: ([SavedShot]) -> Double?
    ) -> some View {
        let points = ordered.enumerated().compactMap { index, session in
            value(session.shots).map { Point(index: index, value: $0) }
        }
        return card("\(title) — session average (\(unit))") {
            if points.count >= 2 {
                trendChart(points: points, idealBand: idealBand, domain: domain)
            } else {
                Text("Bowl two sessions with this metric to see a trend.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trendChart(
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

    // MARK: Shared

    private func card<Content: View>(
        _ title: String, footer: String? = nil, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func pocketPercent(of shots: [SavedShot]) -> Double? {
        let entries = shots.filter { $0.entryBoard != nil }
        guard !entries.isEmpty else { return nil }
        return Double(entries.filter(\.isPocketHit).count) / Double(entries.count) * 100
    }

    private func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private func format(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? "--"
    }
}

#Preview {
    StatsView()
        .modelContainer(for: SavedShot.self, inMemory: true)
}
