import PhotosUI
import SwiftUI

/// The primary tab: an entry point that launches the capture flow, either from a
/// live recording or an existing video (useful without lane access).
struct BowlHomeView: View {
    /// Owned by ContentView, which renders the capture flow as a root overlay.
    @Binding var capture: CaptureRoute?
    /// Cold-start entrance: nil renders statically (previews, tab revisits);
    /// non-nil participates in the launch choreography — hidden while false,
    /// landing staggered when it flips true (the curtain starting to lift).
    var entrance: Bool? = nil
    @Environment(TruelineStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

                Text("Every throw,\nmeasured.")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.top, 28)
                    .modifier(landing(1))

                Text("Prop your phone behind the approach and bowl. Speed, line, breakpoint, and entry angle for every shot.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .modifier(landing(2))

                Spacer()

                LaneHeroView()
                    .frame(height: 132)
                    .modifier(landing(3))

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
            index: 5 - index,
            reduceMotion: reduceMotion,
            baseDelay: 0.15,
            step: 0.09
        )
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
/// falls out of the ratio, not the frame), rack depth at 75% of that, and
/// the textbook shot into the 1–3 gap. Decoration, not data.
private struct LaneHeroView: View {
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

            // The textbook shot: soft glow under the mint core
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
            // Breakpoint marker
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
        .background(Color(red: 13 / 255, green: 14 / 255, blue: 15 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    BowlHomeView(capture: .constant(nil))
        .environment(TruelineStore())
}
