import SwiftUI

/// Full-screen capture sequence launched from the Bowl tab. Currently
/// record → review; calibration and analysis steps slot in after review.
struct CaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraModel()

    var body: some View {
        Group {
            if let clipURL = camera.finishedClipURL {
                ClipReviewView(
                    clipURL: clipURL,
                    onRetake: {
                        camera.discardClip()
                    },
                    onUse: {
                        // TODO: hand the clip to the calibration step (task #3).
                        camera.stop()
                        dismiss()
                    }
                )
            } else {
                RecordView(camera: camera) {
                    camera.stop()
                    dismiss()
                }
            }
        }
        .task { await camera.start() }
        .statusBarHidden()
    }
}

#Preview {
    CaptureFlowView()
}
