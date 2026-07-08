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

    @AppStorage("speedUnit") private var speedUnit = "mph"

    var body: some View {
        VStack(spacing: 16) {
            if let clipURL {
                if result.videoDisplaySize.height >= result.videoDisplaySize.width {
                    // Portrait clip: video dominant, thin lane view beside it,
                    // heights matched to a share of the screen so small phones
                    // still see the metrics without scrolling far.
                    HStack(spacing: 12) {
                        VideoPathView(clipURL: clipURL, result: result)
                        LaneViewCanvas(result: result, compact: true)
                            .frame(width: 104)
                    }
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.52 }
                    .frame(maxWidth: .infinity)
                } else {
                    // Landscape clip: no room beside it — stack instead.
                    VideoPathView(clipURL: clipURL, result: result)
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
