import AVKit
import SwiftUI

/// The review step: play back the recorded throw, then keep it or retake.
struct ClipReviewView: View {
    let clipURL: URL
    var onRetake: () -> Void
    var onUse: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                if let player {
                    VideoPlayer(player: player)
                }

                VStack(spacing: 12) {
                    Text("Next: mark the lane corners so the ball path can be measured.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button {
                            onRetake()
                        } label: {
                            Label("Retake", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            onUse()
                        } label: {
                            Label("Use Throw", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding()
                .background(.black)
            }
        }
        .onAppear {
            let player = AVPlayer(url: clipURL)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
