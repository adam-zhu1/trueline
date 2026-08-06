import AVKit
import SwiftUI

/// The review step: play back the recorded throw, then keep it or retake.
struct ClipReviewView: View {
    let clipURL: URL
    /// Imported clips came from the Photos picker, so "retake" means picking a
    /// different video, not opening the camera.
    var isImported = false
    var onRetake: () -> Void
    var onUse: () -> Void
    /// Present when session corners exist; lets the user redo calibration
    /// after moving the phone.
    var onRecalibrate: (() -> Void)?
    /// Leave the flow entirely, discarding the clip — the X in the corner,
    /// same affordance as the record screen.
    var onClose: () -> Void

    @State private var player: AVPlayer?

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
                    VideoPlayer(player: player)
                }

                VStack(spacing: 12) {
                    if onRecalibrate != nil {
                        Button("Phone moved? Recalibrate corners") {
                            onRecalibrate?()
                        }
                        .font(.footnote)
                        .tint(Color.brandMint)
                    }
                    Text(onRecalibrate != nil
                        ? "Corners from this session will be reused."
                        : "Next: mark the lane corners so the ball path can be measured.")
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
        .onDisappear {
            player?.pause()
        }
    }
}
