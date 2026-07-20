import AVKit
import SwiftUI

/// The shot video, looping, with the smoothed ball path drawn on top. Used on
/// fresh results and on saved-shot replays.
struct VideoPathView: View {
    let clipURL: URL
    let result: ShotResult
    var cornerRadius: CGFloat = 12
    /// How much of the tracked line is drawn, 0–1. Animatable (it's a shape
    /// trim), so the result-reveal choreography can draw the line in.
    var pathTrim: CGFloat = 1

    @State private var player: AVPlayer?
    @State private var looper: Any?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            }
            // The container has the video's aspect ratio, so normalized display
            // coordinates map straight onto the view.
            if result.videoPath.count >= 2 {
                TrackedPathShape(points: result.videoPath)
                    .trim(from: 0, to: pathTrim)
                    .stroke(
                        Color.brandMint,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(
            result.videoDisplaySize.width / max(result.videoDisplaySize.height, 1),
            contentMode: .fit
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            // Re-appears reuse the player; the looper observer is re-added
            // fresh each time so it never stacks or outlives the view.
            if player == nil {
                let new = AVPlayer(url: clipURL)
                new.isMuted = true
                player = new
            }
            if let player, looper == nil {
                looper = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    player.seek(to: .zero)
                    player.play()
                }
            }
            player?.play()
        }
        .onDisappear {
            player?.pause()
            if let looper {
                NotificationCenter.default.removeObserver(looper)
                self.looper = nil
            }
        }
    }
}

/// The smoothed ball path in normalized display coordinates, as a Shape so
/// `.trim` can animate it drawing in.
private struct TrackedPathShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: p.x * rect.width, y: p.y * rect.height)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}
