import AVKit
import SwiftUI

/// The review step: play back the recorded throw, then keep it or retake.
/// When the session already has confirmed corners, the throw's first frame is
/// checked against the calibration frame (DriftCheck): a small bump is
/// corrected automatically, a big one asks for a new calibration. The lane
/// overlay is drawn through the corners the throw will actually be analyzed
/// with, so the user can see the result either way.
struct ClipReviewView: View {
    let clipURL: URL
    /// Imported clips came from the Photos picker, so "retake" means picking a
    /// different video, not opening the camera.
    var isImported = false
    /// The session's confirmed calibration, drawn over the clip as the drift
    /// check. nil until the first throw of a session is calibrated.
    var sessionCorners: LaneCorners?
    /// The calibration frame's comparison band. nil skips the automatic check
    /// (first throw, imported clip, or the reference couldn't be read).
    var driftReference: DriftCheck.Reference?
    var onRetake: () -> Void
    /// Hands back the drift check's result when one ran, so the flow can
    /// analyze with the corrected corners and re-anchor the reference.
    var onUse: (DriftCheck.Result?) -> Void
    /// Present when session corners exist; lets the user redo calibration
    /// after moving the phone.
    var onRecalibrate: (() -> Void)?
    /// Leave the flow entirely, discarding the clip — the X in the corner,
    /// same affordance as the record screen.
    var onClose: () -> Void

    @State private var player: AVPlayer?
    /// Display-oriented pixel size of the clip, for aligning the overlay.
    @State private var videoSize: CGSize?
    @State private var drift: DriftCheck.Result?

    /// Corners the throw will be analyzed with: corrected when the check
    /// passed, the session's otherwise.
    private var overlayCorners: LaneCorners? {
        drift?.corners ?? sessionCorners
    }

    private var phoneMoved: Bool {
        drift?.verdict == .recalibrate
    }

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
                            if let overlayCorners, let videoSize {
                                LaneOverlayView(
                                    corners: overlayCorners,
                                    imageSize: videoSize,
                                    fittedRect: LaneOverlayView.fittedRect(imageSize: videoSize, in: geo.size)
                                )
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    if onRecalibrate != nil && !phoneMoved {
                        Button("Phone moved? Recalibrate corners") {
                            onRecalibrate?()
                        }
                        .font(.footnote)
                        .tint(Color.brandMint)
                    }
                    Text(reviewCaption)
                        .font(.footnote)
                        .foregroundStyle(phoneMoved ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                    if phoneMoved {
                        Button("Use the old calibration anyway") {
                            onUse(drift)
                        }
                        .font(.footnote)
                        .tint(Color.brandMint)
                    }
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

                        if phoneMoved {
                            Button {
                                onRecalibrate?()
                            } label: {
                                Label("Recalibrate", systemImage: "scope")
                            }
                            .buttonStyle(.primaryAction)
                        } else {
                            Button {
                                onUse(drift)
                            } label: {
                                Label("Use Throw", systemImage: "checkmark")
                            }
                            .buttonStyle(.primaryAction)
                        }
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
            // About 10 ms of registration plus one frame decode, so it's done
            // long before the user has watched the replay.
            guard let sessionCorners, let driftReference else { return }
            drift = await DriftCheck.check(throwClip: clipURL, against: driftReference, corners: sessionCorners)
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
        if phoneMoved {
            return "The phone looks like it moved since you calibrated. Recalibrate so this throw is measured on the right lane."
        }
        if case .corrected(noticeable: true) = drift?.verdict {
            return "The phone shifted a little since you calibrated, so the lane was re-aligned to match. Check that the drawn lane sits on the real one."
        }
        if onRecalibrate != nil {
            return "The drawn lane is this session's calibration. If it slid off the real lane, recalibrate."
        }
        return "Next: mark the lane so the ball path can be measured."
    }
}
