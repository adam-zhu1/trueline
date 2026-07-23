import SwiftUI

/// The one layout a shot renders in — the fresh Shot Result screen and a
/// saved shot opened from History both use this, so the two can't drift
/// apart. With a replay video the compact lane view sits beside it; without
/// one (video off, or deleted from Settings) the lane view takes the stage.
struct ShotResultContent: View {
    let result: ShotResult
    /// Replay video to play behind the tracked line, when one exists.
    var clipURL: URL?
    /// Target-line practice: the session's target board at the arrows, when
    /// set — adds a per-throw miss tile.
    var targetBoard: Double? = nil
    /// True when this screen is being revealed fresh from an analysis: the
    /// curtain lifts on the complete layout and the tracked line then draws
    /// itself in — the one flourish. False (History) shows everything in
    /// place, line included.
    var reveal = false

    @AppStorage("speedUnit") private var speedUnit = "mph"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFullScreenVideo = false
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 16) {
            if let clipURL {
                if result.videoDisplaySize.height >= result.videoDisplaySize.width {
                    // Portrait clip: the recording takes its natural width
                    // from the row height, and the lane view gets ALL the
                    // remaining width — no fixed panel width, no dead space
                    // at the sides on wide phones.
                    GeometryReader { geo in
                        let aspect = result.videoDisplaySize.width
                            / max(result.videoDisplaySize.height, 1)
                        let videoW = min(geo.size.height * aspect, geo.size.width * 0.66)
                        HStack(spacing: 12) {
                            expandableVideo(clipURL)
                                .frame(width: videoW)
                            LaneViewCanvas(result: result, compact: true)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.54 }
                    .frame(maxWidth: .infinity)
                } else {
                    // Landscape clip: no room beside it — stack instead.
                    expandableVideo(clipURL)
                    LaneViewCanvas(result: result, compact: true)
                        .frame(height: 320)
                }
            } else {
                LaneViewCanvas(result: result)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Speed",
                    value: format(result.speedMph.map { SpeedUnit.value($0, unit: speedUnit) }),
                    unit: SpeedUnit.label(speedUnit)
                )
                MetricTile(title: "Board at Arrows", value: format(result.arrowBoard), unit: "board")
                if let targetBoard {
                    let miss = result.arrowBoard.map { $0 - targetBoard }
                    MetricTile(
                        title: "vs Target \(Int(targetBoard))",
                        value: miss.map { String(format: "%+.1f", $0) } ?? "--",
                        unit: "boards",
                        numeric: miss, ideal: -1...1
                    )
                }
                MetricTile(title: "Launch Angle", value: format(result.launchAngleDegrees), unit: "°")
                MetricTile(
                    title: "Entry Board", value: format(result.entryBoard), unit: "board",
                    numeric: result.entryBoard, ideal: ShotResult.pocketBoards
                )
                MetricTile(
                    title: "Entry Angle", value: format(result.entryAngleDegrees), unit: "°",
                    numeric: result.entryAngleDegrees, ideal: 4...6
                )
                MetricTile(title: "Breakpoint", value: format(result.breakpointBoard), unit: "board")
                MetricTile(
                    title: "Breakpoint Distance",
                    value: result.breakpointFeet.map { String(format: "%.0f", $0) } ?? "--",
                    unit: "ft"
                )
                MetricTile(title: "Hook", value: format(result.hookBoards), unit: "boards")
            }

            if looksMiscalibrated {
                Label(
                    "These numbers are outside typical ranges — if the phone moved during the session, recalibrate the corners on your next throw.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if result.speedMph == nil {
                Text("Speed needs the ball tracked through the front of the lane — start recording before the throw.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if result.trackedFrames < 10 {
                Text("The ball couldn't be tracked reliably in this clip. Check that the throw is visible and the corners match the lane.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            guard reveal, !revealed else { return }
            // The curtain reveals bottom-first and the recording sits at the
            // top, so the draw waits until its area is actually uncovered.
            withAnimation(
                reduceMotion
                    ? .easeIn(duration: 0.3).delay(0.5)
                    : .easeInOut(duration: 0.9).delay(0.75)
            ) {
                revealed = true
            }
        }
    }

    /// The replay, tappable to go full screen — a small expand glyph in the
    /// corner makes the option visible. The in-place player is a muted loop
    /// with no controls, so the whole surface can take the tap.
    private func expandableVideo(_ clipURL: URL) -> some View {
        VideoPathView(clipURL: clipURL, result: result, pathTrim: !reveal || revealed ? 1 : 0)
            .allowsHitTesting(false)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .padding(8)
                    .background(.black.opacity(0.45), in: Circle())
                    .foregroundStyle(.white)
                    .padding(8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { showFullScreenVideo = true }
            .fullScreenCover(isPresented: $showFullScreenVideo) {
                FullScreenVideoView(clipURL: clipURL, result: result)
            }
    }

    /// Stale or wrong calibration produces numbers that look like data (a
    /// miscalibrated test clip read 27 mph over board 30) — flag anything
    /// outside plausible league ranges instead of presenting it deadpan.
    private var looksMiscalibrated: Bool {
        if let speed = result.speedMph, speed > 24 || speed < 6 { return true }
        if let arrows = result.arrowBoard, arrows >= 30 { return true }
        return false
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}

/// The replay at full size with the tracked line still drawn on it. Unlike
/// the in-place loop this one keeps the player's native controls, so the
/// throw can be scrubbed frame by frame.
struct FullScreenVideoView: View {
    let clipURL: URL
    let result: ShotResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPathView(clipURL: clipURL, result: result, cornerRadius: 0)
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(.white.opacity(0.12), in: Circle())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
    }
}
