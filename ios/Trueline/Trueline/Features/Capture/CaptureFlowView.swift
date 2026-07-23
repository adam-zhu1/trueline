import SwiftUI

/// Full-screen capture sequence launched from the Bowl tab:
/// record → review → calibrate → analyze → results.
struct CaptureFlowView: View {
    private enum Step: Equatable {
        case record
        case review(URL)
        /// Out of free throws with a clip in hand — the gate sits between
        /// review and analysis so the recording itself is never blocked.
        case paywall(URL)
        case calibrate(URL)
        case analyze(URL, LaneCorners)
        case results(URL, ShotResult)
        case trackingFailed(URL)

        static func == (lhs: Step, rhs: Step) -> Bool {
            switch (lhs, rhs) {
            case (.record, .record): true
            case (.review(let a), .review(let b)): a == b
            case (.paywall(let a), .paywall(let b)): a == b
            case (.calibrate(let a), .calibrate(let b)): a == b
            case (.analyze(let a, let c), .analyze(let b, let d)): a == b && c == d
            case (.results(let a, _), .results(let b, _)): a == b
            case (.trackingFailed(let a), .trackingFailed(let b)): a == b
            default: false
            }
        }
    }

    @Environment(TruelineStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var camera = CameraModel()
    @State private var step: Step
    /// Corners from the first calibration of this session; later throws reuse
    /// them (the phone doesn't move between throws).
    @State private var sessionCorners: LaneCorners?
    @State private var session: BowlingSession?
    /// Target-line practice: set from the record screen, scored on results,
    /// persisted onto the session.
    @State private var targetBoard: Double?
    private let isImported: Bool
    /// Closes the root overlay this flow renders in (there is no presentation
    /// to dismiss).
    private let onExit: () -> Void

    /// Pass an imported clip to skip recording and start at review.
    init(importedClipURL: URL? = nil, onExit: @escaping () -> Void) {
        _step = State(initialValue: importedClipURL.map(Step.review) ?? .record)
        isImported = importedClipURL != nil
        self.onExit = onExit
    }

    var body: some View {
        Group {
            switch step {
            case .record:
                RecordView(camera: camera, targetBoard: $targetBoard) {
                    camera.stop()
                    onExit()
                }
            case .review(let clipURL):
                ClipReviewView(
                    clipURL: clipURL,
                    isImported: isImported,
                    onRetake: {
                        if isImported {
                            // No camera to retake with — back to the Photos
                            // picker on the home screen.
                            try? FileManager.default.removeItem(at: clipURL)
                            onExit()
                        } else {
                            camera.discardClip()
                            step = .record
                        }
                    },
                    onUse: {
                        if store.canAnalyze {
                            startAnalysis(of: clipURL)
                        } else {
                            step = .paywall(clipURL)
                        }
                    },
                    onRecalibrate: sessionCorners == nil ? nil : {
                        step = .calibrate(clipURL)
                    }
                )
            case .paywall(let clipURL):
            PaywallView {
                // Unlocked: the throw they just bowled goes straight through.
                // Dismissed: back to review — the clip isn't thrown away.
                if store.canAnalyze {
                    startAnalysis(of: clipURL)
                } else {
                    step = .review(clipURL)
                }
            }
        case .calibrate(let clipURL):
                CalibrationView(
                    clipURL: clipURL,
                    preferSavedCalibration: !isImported,
                    onBack: {
                        step = .review(clipURL)
                    },
                    onConfirm: { corners in
                        // Imported clips come from arbitrary cameras — only a
                        // live placement is worth remembering for next time.
                        if !isImported {
                            corners.saveAsLastConfirmed()
                        }
                        sessionCorners = corners
                        step = .analyze(clipURL, corners)
                    }
                )
            case .analyze(let clipURL, let corners):
                AnalysisView(
                    clipURL: clipURL,
                    corners: corners,
                    onComplete: { result in
                        if result.isReliable {
                            // The only place quota is spent: a reliable
                            // result. Failed tracking falls through free.
                            store.recordAnalyzedThrow()
                            ensureSession()
                            // Instant swap: ResultsView(reveal:) overlays a
                            // frozen copy of the loader's final frame and
                            // lifts it as the curtain — no view transition,
                            // so nothing re-lays-out mid-slide.
                            step = .results(clipURL, result)
                        } else {
                            step = .trackingFailed(clipURL)
                        }
                    },
                    onFailed: {
                        step = .trackingFailed(clipURL)
                    },
                    onCancel: {
                        step = .review(clipURL)
                    }
                )
            case .results(let clipURL, let result):
                ResultsView(clipURL: clipURL, result: result, session: session, targetBoard: targetBoard, reveal: true) {
                    if isImported {
                        try? FileManager.default.removeItem(at: clipURL)
                        camera.stop()
                        onExit()
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
                        if isImported {
                            try? FileManager.default.removeItem(at: clipURL)
                        } else {
                            camera.discardClip()
                        }
                        camera.stop()
                        onExit()
                    }
                )
            }
        }
        .onChange(of: camera.finishedClipURL) { _, clipURL in
            if let clipURL { step = .review(clipURL) }
        }
    }

    /// First calibration of a session drags corners; every later throw reuses
    /// them and skips straight to analysis.
    private func startAnalysis(of clipURL: URL) {
        if let corners = sessionCorners {
            step = .analyze(clipURL, corners)
        } else {
            step = .calibrate(clipURL)
        }
    }

    /// The session shots get saved into — created on the first successful
    /// analysis, only for live recording flows (imported one-offs stay
    /// sessionless). Runs from the analysis completion callback: inserting a
    /// model while SwiftUI is evaluating a body is a state-mutation-during-
    /// update, which is exactly the kind of thing that breaks presentations.
    private func ensureSession() {
        guard !isImported else { return }
        if session == nil {
            let new = BowlingSession()
            modelContext.insert(new)
            session = new
        }
        // Keep the session's target in step with the record-screen chip, so
        // History scores throws against what was actually aimed at.
        session?.targetBoard = targetBoard
    }
}

#Preview {
    CaptureFlowView(onExit: {})
        .environment(TruelineStore())
}
