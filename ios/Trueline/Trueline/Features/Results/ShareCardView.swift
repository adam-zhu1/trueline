import SwiftUI

/// The shareable shot image: lane view + metrics in a fixed 4:5 card (fits
/// Instagram/social posts without cropping). Rendered off-screen by
/// ShotShareButton — never displayed live, so it can use fixed dimensions
/// instead of adapting to the device.
struct ShareCardView: View {
    let result: ShotResult
    let date: Date
    /// Session tag line (ball · center · pattern), when set.
    var tags: [String] = []
    var speedUnit = "mph"

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                (Text("True").foregroundStyle(.white) + Text("Line").foregroundStyle(Color.brandMint))
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                LaneViewCanvas(result: result)
                    .frame(width: 200)

                VStack(alignment: .leading, spacing: 14) {
                    metric("Speed", format(result.speedMph.map { SpeedUnit.value($0, unit: speedUnit) }), SpeedUnit.label(speedUnit))
                    metric("Arrows", format(result.arrowBoard), "board")
                    metric("Launch", format(result.launchAngleDegrees), "°")
                    metric("Breakpoint", format(result.breakpointBoard), "board")
                    metric(
                        "Entry Board", format(result.entryBoard), "board",
                        mint: result.entryBoard.map { (17.0...18.0).contains($0) } ?? false
                    )
                    metric(
                        "Entry Angle", format(result.entryAngleDegrees), "°",
                        mint: result.entryAngleDegrees.map { (4.0...6.0).contains($0) } ?? false
                    )
                    Spacer(minLength: 0)
                }
            }

            HStack {
                Text(tags.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("Every throw, measured")
                    .font(.caption2)
                    .foregroundStyle(Color.brandMintDim)
            }
        }
        .padding(20)
        .frame(width: 360, height: 450)
        .background(Color(red: 12 / 255, green: 12 / 255, blue: 14 / 255))
        .environment(\.colorScheme, .dark)
    }

    private func metric(_ title: String, _ value: String, _ unit: String, mint: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(mint ? Color.brandMint : .white)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}

/// Toolbar share button for a shot: renders the card at 3× (1080×1350) and
/// hands it to the system share sheet. Re-renders if the speed unit changes.
struct ShotShareButton: View {
    let result: ShotResult
    let date: Date
    var tags: [String] = []

    @AppStorage("speedUnit") private var speedUnit = "mph"
    @State private var card: Image?

    var body: some View {
        Group {
            if let card {
                ShareLink(
                    item: card,
                    preview: SharePreview(
                        "TrueLine · \(date.formatted(date: .abbreviated, time: .omitted))",
                        image: card
                    )
                )
            } else {
                // Placeholder while the card renders — an empty toolbar item
                // is never installed, so its .task would never fire.
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: speedUnit) {
            let renderer = ImageRenderer(
                content: ShareCardView(result: result, date: date, tags: tags, speedUnit: speedUnit)
            )
            renderer.scale = 3
            card = renderer.uiImage.map(Image.init(uiImage:))
        }
    }
}

#if DEBUG
extension ShotResult {
    /// Sample shot for previews and the -shareCardPreview debug hook.
    static var sampleCard: ShotResult {
        // Skid to the breakpoint, then hook to the pocket — the markers must
        // sit on the path or the sample reads as a rendering bug.
        func board(at ft: Double) -> Double {
            ft <= 42
                ? 18 - (18 - 6.8) * (ft / 42)
                : 6.8 + (17.3 - 6.8) * pow((ft - 42) / 17.5, 1.3)
        }
        return ShotResult(
            speedMph: 17.2,
            arrowBoard: board(at: 15),
            breakpointBoard: 6.8,
            breakpointFeet: 42,
            entryAngleDegrees: 4.1,
            entryBoard: 17.3,
            launchAngleDegrees: 2.4,
            path: stride(from: 0.0, through: 59.5, by: 0.5).map { (board: board(at: $0), feet: $0) },
            videoPath: [],
            videoDisplaySize: CGSize(width: 1080, height: 1920),
            trackedFrames: 120
        )
    }
}

#Preview {
    ShareCardView(
        result: .sampleCard,
        date: .now,
        tags: ["Phaze II", "Kingpin Lanes", "House"]
    )
}
#endif
