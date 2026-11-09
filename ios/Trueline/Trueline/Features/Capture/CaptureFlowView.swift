import SwiftUI

/// Full-screen capture sequence launched from the Bowl tab:
/// record → review → calibrate → analyze → results.
///
/// Every way forward from a reviewed clip (Use, Recalibrate, and the paywall
/// closing after a purchase) goes through `ReviewRoute.next`, so the free
/// throw gate can't be skipped by picking a different button.
enum ReviewRoute: Equatable {
    case paywall
    case calibrate
    case analyze

    static func next(canAnalyze: Bool, recalibrating: Bool, hasSessionCorners: Bool) -> ReviewRoute {
        guard canAnalyze else { return .paywall }
        return recalibrating || !hasSessionCorners ? .calibrate : .analyze
    }
}

struct CaptureFlowView: View {
    private enum Step: Equatable {
        case record
        case review(URL)
        /// Out of free throws with a clip in hand — the gate sits between
        /// review and analysis so the recording itself is never blocked.
        /// `recalibrating` remembers which button led here, so an unlock
        /// carries on to the screen the user asked for.
        case paywall(URL, recalibrating: Bool)
        case calibrate(URL)
        case analyze(URL, LaneCorners)
        case results(URL, ShotResult)
        case trackingFailed(URL, TrackingFailure)

        static func == (lhs: Step, rhs: Step) -> Bool {
            switch (lhs, rhs) {
            case (.record, .record): true
            case (.review(let a), .review(let b)): a == b
            case (.paywall(let a, let c), .paywall(let b, let d)): a == b && c == d
            case (.calibrate(let a), .calibrate(let b)): a == b
            case (.analyze(let a, let c), .analyze(let b, let d)): a == b && c == d
            case (.results(let a, _), .results(let b, _)): a == b
            case (.trackingFailed(let a, let c), .trackingFailed(let b, let d)): a == b && c == d
            default: false
            }
        }
    }

    @Environment(TruelineStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var camera = CameraModel()
    @State private var step: Step
    /// Corners from the first calibration of this session; later throws reuse
    /// them, carried through the drift check when the phone was bumped.
    @State private var sessionCorners: LaneCorners?
    /// The frame `sessionCorners` describe, as DriftCheck's comparison band.
    /// Replaced by each corrected throw so slow sag never builds up.
    @State private var sessionReference: DriftCheck.Reference?
    @State private var session: BowlingSession?
    /// Target-line practice: set from the record screen, scored on results,
    /// persisted onto the session.
    @State private var targetBoard: Double?
    private let isImported: Bool
    /// Closes the root overlay this flow renders in (there is no presentation
    /// to dismiss).
    private let onExit: () -> Void
    /// "Pick Another" on an imported clip: exit AND reopen the picker.
    /// nil falls back to a plain exit.
    private let onRepick: (() -> Void)?

    /// Pass an imported clip to skip recording and start at review.
    init(importedClipURL: URL? = nil, onExit: @escaping () -> Void, onRepick: (() -> Void)? = nil) {
        _step = State(initialValue: importedClipURL.map(Step.review) ?? .record)
        isImported = importedClipURL != nil
        self.onExit = onExit
        self.onRepick = onRepick
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
                    sessionCorners: sessionCorners,
                    driftReference: sessionReference,
                    onRetake: {
                        if isImported {
                            // No camera to retake with — back to the Photos
                            // picker, reopened by the home screen.
                            try? FileManager.default.removeItem(at: clipURL)
                            (onRepick ?? onExit)()
                        } else {
                            camera.discardClip()
                            step = .record
                        }
                    },
                    onUse: { drift in
                        // A passed check re-anchors the session on this
                        // throw. "Use the old calibration anyway" after a
                        // failed one keeps everything as it was.
                        if let drift, drift.verdict != .recalibrate {
                            sessionCorners = drift.corners
                            sessionReference = drift.reference
                        }
                        proceed(with: clipURL, recalibrating: false)
                    },
                    onRecalibrate: sessionCorners == nil ? nil : {
                        proceed(with: clipURL, recalibrating: true)
                    },
                    onClose: {
                        if isImported {
                            try? FileManager.default.removeItem(at: clipURL)
                        } else {
                            camera.discardClip()
                        }
                        camera.stop()
                        onExit()
                    }
                )
            case .paywall(let clipURL, let recalibrating):
            PaywallView {
                // Unlocked: the throw they just bowled goes straight through.
                // Dismissed: back to review — the clip isn't thrown away.
                if store.canAnalyze {
                    proceed(with: clipURL, recalibrating: recalibrating)
                } else {
                    step = .review(clipURL)
                }
            }
        case .calibrate(let clipURL):
                CalibrationView(
                    clipURL: clipURL,
                    preferSavedCalibration: !isImported,
                    captureZoom: camera.zoomFactor,
                    onBack: {
                        step = .review(clipURL)
                    },
                    onConfirm: { corners in
                        // Imported clips come from arbitrary cameras — only a
                        // live placement is worth remembering for next time.
                        if !isImported {
                            corners.saveAsLastConfirmed(zoom: camera.zoomFactor)
                        }
                        sessionCorners = corners
                        // The corners were set on this clip's first frame, so
                        // that frame is the new drift reference. Cleared first
                        // so nothing compares new corners to an old frame.
                        sessionReference = nil
                        if !isImported {
                            Task {
                                let reference = await DriftCheck.reference(fromClip: clipURL)
                                // A later recalibration may have landed first.
                                if sessionCorners == corners { sessionReference = reference }
                            }
                        }
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
                            ReviewPrompt.recordSuccessfulAnalysis()
                            ensureSession()
                            // Instant swap: ResultsView(reveal:) overlays a
                            // frozen copy of the loader's final frame and
                            // lifts it as the curtain — no view transition,
                            // so nothing re-lays-out mid-slide.
                            step = .results(clipURL, result)
                        } else {
                            step = .trackingFailed(clipURL, result.failure ?? .lostEarly)
                        }
                    },
                    onFailed: {
                        step = .trackingFailed(clipURL, .unreadableVideo)
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
            case .trackingFailed(let clipURL, let failure):
                TrackingFailedView(
                    failure: failure,
                    // Unlocked users have no quota to reassure about.
                    showsFreeThrowNote: !store.isUnlocked,
                    onAdjustCorners: { step = .calibrate(clipURL) },
                    onRecordAgain: isImported ? nil : {
                        camera.discardClip()
                        step = .record
                    },
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
        .onChange(of: camera.zoomFactor) {
            // A different zoom is a different frame — this session's corners
            // no longer describe it, so the next throw recalibrates.
            sessionCorners = nil
            sessionReference = nil
        }
    }

    /// First calibration of a session drags corners; every later throw reuses
    /// them and skips straight to analysis.
    private func proceed(with clipURL: URL, recalibrating: Bool) {
        switch ReviewRoute.next(
            canAnalyze: store.canAnalyze,
            recalibrating: recalibrating,
            hasSessionCorners: sessionCorners != nil
        ) {
        case .paywall: step = .paywall(clipURL, recalibrating: recalibrating)
        case .calibrate: step = .calibrate(clipURL)
        case .analyze:
            if let corners = sessionCorners { step = .analyze(clipURL, corners) }
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
