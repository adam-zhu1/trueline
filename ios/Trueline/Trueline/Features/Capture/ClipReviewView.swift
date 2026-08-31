import AVKit
import SwiftUI

/// The review step: play back the recorded throw, then keep it or retake.
/// When the session already has confirmed corners, the calibration's lane
/// overlay is drawn over the playback — a bumped phone shows up immediately
/// as the drawn lane sliding off the real one, before the throw is analyzed
/// with stale corners.
struct ClipReviewView: View {
    let clipURL: URL
    /// Imported clips came from the Photos picker, so "retake" means picking a
    /// different video, not opening the camera.
    var isImported = false
    /// The session's confirmed calibration, drawn over the clip as the drift
    /// check. nil until the first throw of a session is calibrated.
    var sessionCorners: LaneCorners?
    var onRetake: () -> Void
    var onUse: () -> Void
    /// Present when session corners exist; lets the user redo calibration
    /// after moving the phone.
    var onRecalibrate: (() -> Void)?
    /// Leave the flow entirely, discarding the clip — the X in the corner,
    /// same affordance as the record screen.
    var onClose: () -> Void

    @State private var player: AVPlayer?
    /// Display-oriented pixel size of the clip, for aligning the overlay.
    @State private var videoSize: CGSize?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // The X gets its own row above the player — floated over the
                // video it fights the playback controls and reads as part of
                // the clip.
                HStack {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                if let player {
                    GeometryReader { geo in
                        ZStack {
                            VideoPlayer(player: player)
                            if let sessionCorners, let videoSize {
                                LaneOverlayView(
                                    corners: sessionCorners,
                                    imageSize: videoSize,
                                    fittedRect: LaneOverlayView.fittedRect(imageSize: videoSize, in: geo.size)
                                )
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    if onRecalibrate != nil {
                        Button("Phone moved? Recalibrate corners") {
                            onRecalibrate?()
                        }
                        .font(.footnote)
                        .tint(Color.brandMint)
                    }
                    Text(reviewCaption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button {
                            onRetake()
                        } label: {
                            Label(
                                isImported ? "Pick Another" : "Retake",
                                systemImage: isImported ? "photo.on.rectangle" : "arrow.counterclockwise"
                            )
                        }
                        .buttonStyle(.secondaryAction)

                        Button {
                            onUse()
                        } label: {
                            Label("Use Throw", systemImage: "checkmark")
                        }
                        .buttonStyle(.primaryAction)
                    }
                }
                .padding()
                .background(.black)
            }
        }
        .onAppear {
            let player = AVPlayer(url: clipURL)
            // Live recordings have no audio track; imported clips might, and
            // review is a muted surface like every replay in the app — no
            // imported soundtrack mixing over the bowler's own music.
            player.isMuted = true
            self.player = player
            player.play()
        }
        .task {
            guard sessionCorners != nil else { return }
            let asset = AVURLAsset(url: clipURL)
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let (size, transform) = try? await track.load(.naturalSize, .preferredTransform)
            else { return }
            let displayed = size.applying(transform)
            videoSize = CGSize(width: abs(displayed.width), height: abs(displayed.height))
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var reviewCaption: String {
        if onRecalibrate != nil {
            return "The drawn lane is this session's calibration. If it slid off the real lane, recalibrate."
        }
        return "Next: mark the lane so the ball path can be measured."
    }
}
