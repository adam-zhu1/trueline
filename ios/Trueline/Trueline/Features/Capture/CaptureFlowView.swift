import SwiftUI

/// Full-screen capture sequence launched from the Bowl tab. Currently
/// record → review → calibrate; analysis slots in after calibration.
struct CaptureFlowView: View {
    private enum Step: Equatable {
        case record
        case review(URL)
        case calibrate(URL)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraModel()
    @State private var step: Step

    /// Pass an imported clip to skip recording and start at review.
    init(importedClipURL: URL? = nil) {
        _step = State(initialValue: importedClipURL.map(Step.review) ?? .record)
    }

    var body: some View {
        Group {
            switch step {
            case .record:
                RecordView(camera: camera) {
                    camera.stop()
                    dismiss()
                }
            case .review(let clipURL):
                ClipReviewView(
                    clipURL: clipURL,
                    onRetake: {
                        camera.discardClip()
                        step = .record
                    },
                    onUse: {
                        step = .calibrate(clipURL)
                    }
                )
            case .calibrate(let clipURL):
                CalibrationView(
                    clipURL: clipURL,
                    onBack: {
                        step = .review(clipURL)
                    },
                    onConfirm: { corners in
                        // TODO: run the analysis pipeline with the calibrated
                        // corners once it's ported (tasks #5/#6).
                        _ = corners
                        camera.stop()
                        dismiss()
                    }
                )
            }
        }
        .onChange(of: camera.finishedClipURL) { _, clipURL in
            if let clipURL { step = .review(clipURL) }
        }
        .statusBarHidden()
    }
}

#Preview {
    CaptureFlowView()
}
