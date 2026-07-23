import PhotosUI
import SwiftData
import SwiftUI

/// The primary tab: an entry point that launches the capture flow, either from
/// a live recording or an existing video (useful without lane access). Two
/// states (empty-state research: design first-run and populated separately):
/// a brand-new user gets the poster — headline, explainer, textbook hero —
/// and once shots exist the screen becomes a mirror: your last session's
/// lines in the hero, a stat strip, and real recent shots. One dominant CTA
/// in both.
struct BowlHomeView: View {
    /// Owned by ContentView, which renders the capture flow as a root overlay.
    @Binding var capture: CaptureRoute?
    /// Cold-start entrance: nil renders statically (previews, tab revisits);
    /// non-nil participates in the launch choreography — hidden while false,
    /// landing staggered when it flips true (the curtain starting to lift).
    var entrance: Bool? = nil
    @Environment(TruelineStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \SavedShot.date, order: .reverse) private var shots: [SavedShot]
    @Query(sort: \BowlingSession.date, order: .reverse) private var sessions: [BowlingSession]
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importFailed = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                (Text("True").foregroundStyle(.white) + Text("Line").foregroundStyle(Color.brandMint))
                    .font(.headline)
                    .padding(.top, 8)
                    .modifier(landing(0))

                if shots.isEmpty {
                    posterHeader
                } else {
                    mirrorHeader
                }

                Spacer()

                LaneHeroView(
                    sessionPaths: heroPaths,
                    drawLines: entrance ?? true
                )
                .frame(height: 132)
                .modifier(landing(3))

                if !shots.isEmpty {
                    statStrip
                        .padding(.top, 14)
                        .modifier(landing(3))
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        if store.canAnalyze {
                            present(.record)
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("Start Session", systemImage: "record.circle.fill")
                    }
                    .buttonStyle(.primaryAction)
                    .modifier(landing(4))

                    // Out of free throws: the picker would just funnel into a
                    // gate anyway, so go straight to the paywall.
                    Group {
                        if store.canAnalyze {
                            PhotosPicker(selection: $pickerItem, matching: .videos) {
                                importLabel
                            }
                            .buttonStyle(.secondaryAction)
                            .disabled(isImporting)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                importLabel
                            }
                            .buttonStyle(.secondaryAction)
                        }
                    }
                    .modifier(landing(5))
                }

                if speedTrendValues.count >= 3 {
                    speedTrend
                        .padding(.top, 22)
                        .modifier(landing(6))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                isImporting = true
                Task {
                    let file = try? await item.loadTransferable(type: VideoFile.self)
                    pickerItem = nil
                    isImporting = false
                    // The overlay can appear while the picker sheet is still
                    // animating away — the sheet just slides off to reveal it.
                    // No presentation to race, so no grace timer.
                    if let file {
                        present(.imported(file.url))
                    } else {
                        // Silent failure reads as a broken button.
                        importFailed = true
                    }
                }
            }
            .alert("Couldn't load that video", isPresented: $importFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a different video — it may still be downloading from iCloud.")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
            }
        }
    }

    /// Entrance for one element. The launch curtain lifts bottom-first, so
    /// the stagger runs bottom-up — each element is already landing as the
    /// mint clears it, instead of the top rows animating under cover.
    private func landing(_ index: Int) -> EntranceLanding {
        EntranceLanding(
            active: entrance != nil,
            shown: entrance ?? true,
            index: 6 - index,
            reduceMotion: reduceMotion,
            baseDelay: 0.15,
            step: 0.09
        )
    }

    // MARK: First-run poster vs returning mirror

    /// The brand-new-user poster: what the app is, before there's data.
    @ViewBuilder
    private var posterHeader: some View {
        Text("Every throw,\nmeasured.")
            .font(.system(size: 40, weight: .bold))
            .padding(.top, 28)
            .modifier(landing(1))

        Text("Prop your phone behind the approach and bowl. Speed, line, breakpoint, and entry angle for every shot.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .modifier(landing(2))
    }

    /// The returning-user greeting: your cadence, not the pitch.
    @ViewBuilder
    private var mirrorHeader: some View {
        Text("Back at it.")
            .font(.system(size: 34, weight: .bold))
            .padding(.top, 28)
            .modifier(landing(1))

        Text(cadenceLine)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .modifier(landing(2))
    }

    /// "2 sessions this week · last Tuesday" — or graceful fallbacks.
    private var cadenceLine: String {
        let calendar = Calendar.current
        let thisWeek = sessions.filter {
            calendar.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear)
                && !$0.shots.isEmpty
        }.count
        var parts: [String] = []
        if thisWeek > 0 {
            parts.append(thisWeek == 1 ? "1 session this week" : "\(thisWeek) sessions this week")
        }
        if let last = shots.first?.date {
            if calendar.isDateInToday(last) {
                parts.append("last threw today")
            } else if calendar.isDateInYesterday(last) {
                parts.append("last threw yesterday")
            } else {
                parts.append("last \(last.formatted(.dateTime.weekday(.wide)))")
            }
        }
        return parts.isEmpty ? "Ready when you are." : parts.joined(separator: " · ")
    }

    /// The hero's lines: the most recent session's throws (chronological, so
    /// the newest draws last and brightest); sessionless imports fall back to
    /// the latest few shots. Empty for first-run — the hero shows the
    /// textbook shot instead.
    private var heroPaths: [[(board: Double, feet: Double)]] {
        let recent: [SavedShot]
        if let session = shots.first?.session, !session.shots.isEmpty {
            recent = session.shots.sorted { $0.date < $1.date }.suffix(4)
        } else {
            recent = shots.prefix(4).reversed()
        }
        return recent.map { zip($0.pathBoards, $0.pathFeet).map { (board: $0, feet: $1) } }
            .filter { $0.count >= 2 }
    }

    /// Last session's numbers (or the recent shots that stand in for one).
    private var statStrip: some View {
        let recent: [SavedShot]
        if let session = shots.first?.session, !session.shots.isEmpty {
            recent = session.shots
        } else {
            recent = Array(shots.prefix(6))
        }
        let speeds = recent.compactMap(\.speedMph)
        let avg = speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)
        let pocket = recent.filter { $0.entryBoard.map(ShotResult.pocketBoards.contains) ?? false }.count
        let bestEntry = recent.compactMap(\.entryAngleDegrees).min { abs($0 - 5) < abs($1 - 5) }

        return HStack(spacing: 0) {
            stat(avg.map { String(format: "%.1f", $0) } ?? "--", unit: "mph", label: "Last avg")
            stat("\(pocket)", unit: "/\(recent.count)", label: "Pocket")
            stat(bestEntry.map { String(format: "%.1f", $0) } ?? "--", unit: "°", label: "Best entry")
        }
    }

    private func stat(_ value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            (Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                + Text(" \(unit)").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ball speed across the last throws, oldest → newest. The one dimension
    /// the hero can't show: change over time.
    private var speedTrendValues: [Double] {
        Array(shots.prefix(12)).reversed().compactMap(\.speedMph)
    }

    /// A quiet sparkline of recent speeds — teases the Stats tab without
    /// repeating the hero (which already shows the lines themselves).
    private var speedTrend: some View {
        let values = speedTrendValues
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("SPEED · LAST \(values.count) THROWS")
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.7)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                if let latest = values.last {
                    (Text(String(format: "%.1f", latest))
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                        + Text(" mph").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)))
                        .monospacedDigit()
                }
            }
            ZStack(alignment: .trailing) {
                SparklineShape(values: values)
                    .stroke(
                        Color.brandMint.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                // The newest throw, marked.
                GeometryReader { geo in
                    if let latest = values.last {
                        Circle()
                            .fill(Color.brandMint)
                            .frame(width: 5, height: 5)
                            .position(
                                x: geo.size.width - 1,
                                y: SparklineShape.y(for: latest, in: values, height: geo.size.height)
                            )
                    }
                }
            }
            .frame(height: 36)
        }
    }

    private var importLabel: some View {
        Label(
            isImporting ? "Importing…" : "Analyze Existing Video",
            systemImage: "photo.on.rectangle"
        )
    }

    private func present(_ route: CaptureRoute) {
        withAnimation(.easeInOut(duration: 0.25)) { capture = route }
    }
}

/// Home-screen hero: a lane on its side — foul line left, pins right — in
/// the instrument lane view's full language AND geometry: points-per-foot
/// length with the standard 3.5× width exaggeration (the strip's thickness
/// falls out of the ratio, not the frame), rack depth at 75% of that. With
/// no data it shows the textbook shot; given `sessionPaths` it becomes the
/// mirror — your session's lines, earlier throws dim, the latest bright,
/// each drawing in once (trim-animated, staggered) when `drawLines` flips.
private struct LaneHeroView: View {
    /// Session lines, chronological — the last is the latest and drawn hero.
    var sessionPaths: [[(board: Double, feet: Double)]] = []
    /// Entrance signal (mirrors the page's landing choreography): false holds
    /// the lines undrawn, flipping true draws them in staggered.
    var drawLines = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ex: Double = 3.5
    private let depthEx: Double = 3.5 * 0.75
    private let surfaceNear = Color(red: 28 / 255, green: 29 / 255, blue: 31 / 255)
    private let surfaceFar = Color(red: 20 / 255, green: 21 / 255, blue: 22 / 255)

    /// Textbook right-hand shot, feet in → boards out (see
    /// feedback-lane-drawing-accuracy): laydown 18.5, breakpoint board 6 at
    /// 42 ft, entry board 17.3 at ~6°.
    private func shotBoard(at feet: Double) -> Double {
        if feet <= 42 {
            let s = sin(feet / 42 * .pi / 2)
            return 18.5 - 12.5 * pow(s, 1.4)
        }
        let t = (feet - 42) / 18
        return 6 + 11.3 * t * t
    }

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 12
            let usable = size.width - inset * 2
            let ppf = usable / (60.0 + 3.0 * depthEx)   // length runs left → right
            let thick = ppf * (41.5 / 12) * ex          // strip thickness, to standard
            let gw = thick * 0.18
            let laneRect = CGRect(
                x: inset, y: (size.height - thick) / 2,
                width: ppf * 60, height: thick
            )
            func fx(_ feet: Double) -> CGFloat { laneRect.minX + ppf * feet }
            func by(_ board: Double) -> CGFloat { laneRect.maxY - thick * (board - 1) / 38.0 }

            // Gutters above and below the strip
            context.fill(
                Path(CGRect(x: laneRect.minX, y: laneRect.minY - gw, width: laneRect.width, height: gw)),
                with: .color(.black.opacity(0.5))
            )
            context.fill(
                Path(CGRect(x: laneRect.minX, y: laneRect.maxY, width: laneRect.width, height: gw)),
                with: .color(.black.opacity(0.5))
            )
            // Surface: near end brighter, fading toward the pins
            context.fill(
                Path(laneRect),
                with: .linearGradient(
                    Gradient(colors: [surfaceNear, surfaceFar]),
                    startPoint: CGPoint(x: laneRect.minX, y: laneRect.midY),
                    endPoint: CGPoint(x: laneRect.maxX, y: laneRect.midY)
                )
            )

            // Board seams: one hairline per arrow board
            for b in stride(from: 5.0, through: 35.0, by: 5.0) {
                var seam = Path()
                seam.move(to: CGPoint(x: laneRect.minX, y: by(b)))
                seam.addLine(to: CGPoint(x: laneRect.maxX, y: by(b)))
                context.stroke(seam, with: .color(.white.opacity(0.05)), lineWidth: 1)
            }

            // Foul line
            var foul = Path()
            foul.move(to: CGPoint(x: fx(0), y: laneRect.minY - gw))
            foul.addLine(to: CGPoint(x: fx(0), y: laneRect.maxY + gw))
            context.stroke(foul, with: .color(Color.brandMintDim), lineWidth: 1.5)

            // Arrows: the V at ~15 ft, center arrow deepest, pointing down-lane
            let arrowSize = min(5, max(2, thick * 0.06))
            for board in stride(from: 5.0, through: 35.0, by: 5.0) {
                let depth = 15 + 1.5 * (1 - abs(board - 20) / 15)
                let pt = CGPoint(x: fx(depth), y: by(board))
                var tri = Path()
                tri.move(to: CGPoint(x: pt.x + arrowSize, y: pt.y))
                tri.addLine(to: CGPoint(x: pt.x - arrowSize * 0.6, y: pt.y - arrowSize * 0.72))
                tri.addLine(to: CGPoint(x: pt.x - arrowSize * 0.6, y: pt.y + arrowSize * 0.72))
                tri.closeSubpath()
                context.fill(tri, with: .color(Color.brandMintDim.opacity(0.85)))
            }

            // Pin rack past the 60 ft line: rows 10.4 in deep
            // (depth-exaggerated), true lateral boards, quiet dots with the
            // pocket pair glowing.
            let rowDX = ppf * (10.4 / 12) * depthEx
            let pinR = max(1.4, min(ppf * (4.75 / 24) * ex, rowDX * 0.42) * 0.7)
            let boardsPer6In = (6.0 / LaneGeometry.laneWidthInches) * 39.0
            context.fill(
                Path(CGRect(
                    x: fx(60) - 2, y: laneRect.minY - gw,
                    width: 3 * rowDX + pinR + 6, height: thick + gw * 2
                )),
                with: .color(.black.opacity(0.35))
            )
            let pinRows: [[Double]] = [[0], [-1, 1], [-2, 0, 2], [-3, -1, 1, 3]]
            for (ri, offsets) in pinRows.enumerated() {
                let px = fx(60) + CGFloat(ri) * rowDX
                for off in offsets {
                    let isPocket = ri == 0 || (ri == 1 && off < 0)
                    let py = by(20.0 + off * boardsPer6In)
                    let pt = CGPoint(x: px, y: py)
                    if isPocket {
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: pt.x - pinR * 2.8, y: pt.y - pinR * 2.8,
                                width: pinR * 5.6, height: pinR * 5.6
                            )),
                            with: .radialGradient(
                                Gradient(colors: [Color.brandMint.opacity(0.28), Color.brandMint.opacity(0)]),
                                center: pt, startRadius: 0, endRadius: pinR * 2.8
                            )
                        )
                    }
                    context.fill(
                        Path(ellipseIn: CGRect(x: pt.x - pinR, y: pt.y - pinR, width: pinR * 2, height: pinR * 2)),
                        with: .color(isPocket ? Color.brandMint.opacity(0.92) : .white.opacity(0.55))
                    )
                }
            }

            // With no session data: the textbook shot, glow + breakpoint.
            // (Session lines render as trim-animatable shapes on top.)
            if sessionPaths.isEmpty {
                var shot = Path()
                for step in 0...60 {
                    let feet = Double(step) / 60 * 59.6
                    let pt = CGPoint(x: fx(feet), y: by(shotBoard(at: feet)))
                    if step == 0 { shot.move(to: pt) } else { shot.addLine(to: pt) }
                }
                context.stroke(
                    shot, with: .color(Color.brandMint.opacity(0.16)),
                    style: StrokeStyle(lineWidth: min(6, thick * 0.12), lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    shot, with: .color(Color.brandMint),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                let bp = CGPoint(x: fx(42), y: by(6))
                context.fill(
                    Path(ellipseIn: CGRect(x: bp.x - 3, y: bp.y - 3, width: 6, height: 6)),
                    with: .color(Color.brandMint)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: bp.x - 3, y: bp.y - 3, width: 6, height: 6)),
                    with: .color(.white), lineWidth: 1
                )
            }
        }
        .overlay {
            // The mirror's lines: earlier throws dim, the latest bright over
            // a glow pass. Trim is animatable, so each line draws in once,
            // staggered, when `drawLines` flips true.
            ForEach(sessionPaths.indices, id: \.self) { i in
                let isLatest = i == sessionPaths.count - 1
                let dimAlpha = 0.14 + 0.07 * Double(i)
                let shape = HeroSessionLineShape(points: sessionPaths[i], ex: ex, depthEx: depthEx)
                    .trim(from: 0, to: drawLines ? 1 : 0)
                ZStack {
                    if isLatest {
                        shape.stroke(
                            Color.brandMint.opacity(0.16),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                        )
                    }
                    shape.stroke(
                        Color.brandMint.opacity(isLatest ? 1 : dimAlpha),
                        style: StrokeStyle(lineWidth: isLatest ? 2 : 1.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .animation(
                    reduceMotion
                        ? .easeIn(duration: 0.3)
                        : .easeOut(duration: 0.65).delay(0.5 + Double(i) * 0.18),
                    value: drawLines
                )
            }
        }
        .background(Color(red: 13 / 255, green: 14 / 255, blue: 15 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// One session line in the hero's sideways lane coordinates. Mirrors the
/// hero canvas's geometry (points-per-foot with the standard exaggerations)
/// so the shapes land exactly on the drawn lane.
private struct HeroSessionLineShape: Shape {
    var points: [(board: Double, feet: Double)]
    var ex: Double
    var depthEx: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        let inset: CGFloat = 12
        let usable = rect.width - inset * 2
        let ppf = usable / (60.0 + 3.0 * depthEx)
        let thick = ppf * (41.5 / 12) * ex
        let laneY = (rect.height - thick) / 2
        for (i, p) in points.enumerated() {
            let pt = CGPoint(
                x: inset + ppf * min(p.feet, 60),
                y: laneY + thick * (1.0 - (p.board - 1) / 38.0)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

/// Recent speeds as a small line, oldest left to newest right, with the
/// vertical range padded so a flat stretch doesn't sit on the edge.
private struct SparklineShape: Shape {
    var values: [Double]

    static func y(for value: Double, in values: [Double], height: CGFloat) -> CGFloat {
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.15, 0.25)
        let range = (hi + pad) - (lo - pad)
        return height * CGFloat(1 - (value - (lo - pad)) / range)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        for (i, v) in values.enumerated() {
            let pt = CGPoint(
                x: rect.minX + rect.width * CGFloat(i) / CGFloat(values.count - 1),
                y: rect.minY + Self.y(for: v, in: values, height: rect.height)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

#Preview {
    BowlHomeView(capture: .constant(nil))
        .environment(TruelineStore())
}
