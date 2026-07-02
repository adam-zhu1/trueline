import SwiftUI

/// Full-screen capture sequence launched from the Bowl tab:
/// record → review → calibrate → analyze → results.
struct CaptureFlowView: View {
    private enum Step: Equatable {
        case record
        case review(URL)
        case calibrate(URL)
        case analyze(URL, LaneCorners)
        case results(URL, ShotResult)
        case trackingFailed(URL)

        static func == (lhs: Step, rhs: Step) -> Bool {
            switch (lhs, rhs) {
            case (.record, .record): true
            case (.review(let a), .review(let b)): a == b
            case (.calibrate(let a), .calibrate(let b)): a == b
            case (.analyze(let a, let c), .analyze(let b, let d)): a == b && c == d
            case (.results(let a, _), .results(let b, _)): a == b
            case (.trackingFailed(let a), .trackingFailed(let b)): a == b
            default: false
            }
        }
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
                        step = .analyze(clipURL, corners)
                    }
                )
            case .analyze(let clipURL, let corners):
                AnalysisView(
                    clipURL: clipURL,
                    corners: corners,
                    onComplete: { result in
                        step = result.isReliable
                            ? .results(clipURL, result)
                            : .trackingFailed(clipURL)
                    },
                    onFailed: {
                        step = .trackingFailed(clipURL)
                    }
                )
            case .results(let clipURL, let result):
                ResultsView(clipURL: clipURL, result: result) {
                    camera.stop()
                    dismiss()
                }
            case .trackingFailed(let clipURL):
                TrackingFailedView(
                    onAdjustCorners: { step = .calibrate(clipURL) },
                    onDiscard: {
                        camera.stop()
                        dismiss()
                    }
                )
            }
        }
        .onChange(of: camera.finishedClipURL) { _, clipURL in
            if let clipURL { step = .review(clipURL) }
        }
    }
}

#Preview {
    CaptureFlowView()
}
