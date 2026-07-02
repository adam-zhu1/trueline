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
    @Environment(\.modelContext) private var modelContext
    @State private var camera = CameraModel()
    @State private var step: Step
    /// Corners from the first calibration of this session; later throws reuse
    /// them (the phone doesn't move between throws).
    @State private var sessionCorners: LaneCorners?
    @State private var session: BowlingSession?
    private let isImported: Bool

    /// Pass an imported clip to skip recording and start at review.
    init(importedClipURL: URL? = nil) {
        _step = State(initialValue: importedClipURL.map(Step.review) ?? .record)
        isImported = importedClipURL != nil
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
                        if let corners = sessionCorners {
                            step = .analyze(clipURL, corners)
                        } else {
                            step = .calibrate(clipURL)
                        }
                    },
                    onRecalibrate: sessionCorners == nil ? nil : {
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
                        sessionCorners = corners
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
                ResultsView(clipURL: clipURL, result: result, session: liveSession()) {
                    if isImported {
                        camera.stop()
                        dismiss()
                    } else {
                        // Back to record for the next throw of this session.
                        camera.discardClip()
                        step = .record
                    }
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

    /// The session shots get saved into — created lazily, only for live
    /// recording flows (imported one-off clips stay sessionless).
    private func liveSession() -> BowlingSession? {
        if isImported { return nil }
        if let session { return session }
        let new = BowlingSession()
        modelContext.insert(new)
        session = new
        return new
    }
}

#Preview {
    CaptureFlowView()
}
