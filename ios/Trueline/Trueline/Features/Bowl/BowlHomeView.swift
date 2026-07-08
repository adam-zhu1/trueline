import PhotosUI
import SwiftUI

/// The primary tab: an entry point that launches the capture flow, either from a
/// live recording or an existing video (useful without lane access).
struct BowlHomeView: View {
    /// Owned by ContentView, which renders the capture flow as a root overlay.
    @Binding var capture: CaptureRoute?
    @Environment(TruelineStore.self) private var store
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

                Text("Every throw,\nmeasured.")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.top, 28)

                Text("Prop your phone behind the approach and bowl. Speed, line, breakpoint, and entry angle for every shot.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                Spacer()

                LaneHeroView()
                    .frame(height: 168)

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

                    // Out of free throws: the picker would just funnel into a
                    // gate anyway, so go straight to the paywall.
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

/// Home-screen hero: a lane on its side — foul line left, pins right — with
/// the brand hook rolling into the pocket. Same neutrals as LaneViewCanvas;
/// decoration, not data.
private struct LaneHeroView: View {
    private let laneFill = Color(red: 55 / 255, green: 55 / 255, blue: 60 / 255)
    private let laneBorder = Color(red: 70 / 255, green: 75 / 255, blue: 80 / 255)
    private let gridColor = Color(red: 65 / 255, green: 70 / 255, blue: 75 / 255)
    private let gutterColor = Color(red: 38 / 255, green: 38 / 255, blue: 40 / 255)

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 14
            let gw: CGFloat = 7
            let lane = CGRect(
                x: inset, y: inset + gw,
                width: size.width - inset * 2,
                height: size.height - (inset + gw) * 2
            )
            // Board 1 is the bottom edge (a right-hander's view rotated to
            // horizontal); u runs foul line → pins, left → right.
            func x(_ u: Double) -> CGFloat { lane.minX + lane.width * u }
            func y(_ board: Double) -> CGFloat { lane.maxY - lane.height * (board - 1) / 38.0 }

            // Gutters + surface
            context.fill(
                Path(CGRect(x: lane.minX, y: lane.minY - gw, width: lane.width, height: gw)),
                with: .color(gutterColor)
            )
            context.fill(
                Path(CGRect(x: lane.minX, y: lane.maxY, width: lane.width, height: gw)),
                with: .color(gutterColor)
            )
            context.fill(Path(lane), with: .color(laneFill))
            context.stroke(Path(lane), with: .color(laneBorder), lineWidth: 1)

            // Board seams
            for b in stride(from: 5.0, through: 35.0, by: 5.0) {
                var seam = Path()
                seam.move(to: CGPoint(x: lane.minX, y: y(b)))
                seam.addLine(to: CGPoint(x: lane.maxX, y: y(b)))
                context.stroke(seam, with: .color(gridColor), lineWidth: 1)
            }

            // Foul line
            var foul = Path()
            foul.move(to: CGPoint(x: x(0), y: lane.minY))
            foul.addLine(to: CGPoint(x: x(0), y: lane.maxY))
            context.stroke(foul, with: .color(Color.brandMintDim), lineWidth: 2)

            // Arrows: the V at 15 ft, center arrow (board 20) deepest
            for board in stride(from: 5.0, through: 35.0, by: 5.0) {
                let u = 0.25 + 0.045 * (1 - abs(board - 20) / 15)
                let pt = CGPoint(x: x(u), y: y(board))
                var tri = Path()
                tri.move(to: CGPoint(x: pt.x + 4.5, y: pt.y))
                tri.addLine(to: CGPoint(x: pt.x - 3, y: pt.y - 4))
                tri.addLine(to: CGPoint(x: pt.x - 3, y: pt.y + 4))
                tri.closeSubpath()
                context.fill(tri, with: .color(Color.brandMintDim))
            }

            // Pin triangle, head pin toward the bowler. True lateral spacing —
            // pins are 12 in apart, so the back row nearly spans the lane
            // (LaneViewCanvas does the same); row depth stays schematic.
            let pinBase = 0.94
            let boardsPer6In = (6.0 / LaneGeometry.laneWidthInches) * 39.0
            for row in 0...3 {
                for i in 0...row {
                    let board = 20.0 + (Double(i) - Double(row) / 2) * 2 * boardsPer6In
                    let pt = CGPoint(x: x(pinBase + Double(row) * 0.016), y: y(board))
                    let isPocket = row == 0 || (row == 1 && i == 0)
                    let pin = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: pin), with: .color(isPocket ? Color.brandMint : Color(white: 0.86)))
                    context.stroke(Path(ellipseIn: pin), with: .color(Color(white: 0.16)), lineWidth: 1)
                }
            }

            // The brand hook, rolling out to the breakpoint and back to the pocket
            var hook = Path()
            for step in 0...40 {
                let u = Double(step) / 40
                let pt = CGPoint(x: x(u * pinBase), y: y(HookCurve.board(at: u)))
                if step == 0 { hook.move(to: pt) } else { hook.addLine(to: pt) }
            }
            context.stroke(
                hook, with: .color(Color.brandMint),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            let ballU = HookCurve.breakpoint
            let ball = CGPoint(x: x(ballU * pinBase), y: y(HookCurve.board(at: ballU)))
            context.fill(
                Path(ellipseIn: CGRect(x: ball.x - 4.5, y: ball.y - 4.5, width: 9, height: 9)),
                with: .color(Color.brandMint)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: ball.x - 4.5, y: ball.y - 4.5, width: 9, height: 9)),
                with: .color(.white), lineWidth: 1
            )
        }
        .background(Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    BowlHomeView(capture: .constant(nil))
        .environment(TruelineStore())
}
