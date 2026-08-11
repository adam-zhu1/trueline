import AVFoundation
import Observation

/// Owns the capture session for the record step. Video only — analysis doesn't need
/// audio, and skipping it avoids the microphone permission prompt.
@Observable
@MainActor
final class CameraModel {
    enum Status {
        /// Not yet configured.
        case idle
        /// Session running, preview live.
        case previewing
        /// User declined camera permission.
        case denied
        /// No usable camera (e.g. simulator) or configuration failed.
        case failed
    }

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let recordingDelegate = RecordingDelegate()

    private(set) var status: Status = .idle
    private(set) var isRecording = false

    init() {
        // A prior denial is knowable synchronously. Setting it here, before
        // the first frame, lets the record screen's explanation ride the
        // presentation slide instead of popping in after it. (.notDetermined
        // stays idle — that path shows the system prompt from start().)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            status = .denied
        default:
            break
        }
    }
    private(set) var recordingStartedAt: Date?
    /// Set when a recording finishes successfully; observed by the capture flow.
    private(set) var finishedClipURL: URL?

    func start() async {
        guard status == .idle else { return }
        guard await isAuthorized() else {
            status = .denied
            return
        }
        // Configuration blocks for hundreds of ms creating the device input —
        // do it with startRunning, off the main actor, so the record screen's
        // slide-up never hitches on it.
        let session = session
        let movieOutput = movieOutput
        let configured = await Task.detached(priority: .userInitiated) {
            do {
                try Self.configure(session: session, movieOutput: movieOutput)
            } catch {
                return false
            }
            // After the commit — applying the preset can reset the format,
            // and with it any frame durations set during configuration.
            Self.requestSixtyFPS(session: session)
            session.startRunning()
            return true
        }.value
        status = configured ? .previewing : .failed
    }

    func stop() {
        if isRecording { movieOutput.stopRecording() }
        let session = session
        Task.detached { session.stopRunning() }
    }

    func startRecording() {
        guard status == .previewing, !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("throw-\(UUID().uuidString).mov")
        recordingDelegate.onFinish = { [weak self] url, error in
            Task { @MainActor in
                // Interruptions (call, lock, disk limit) usually finalize a
                // playable file — AVFoundation flags that on the error.
                let finished = error == nil || ((error as NSError?)?
                    .userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true)
                self?.isRecording = false
                self?.recordingStartedAt = nil
                if let self, finished {
                    // Durable the moment it exists (same-volume clone) —
                    // every later cleanup can treat the tmp file as
                    // disposable, and no exit path can lose the throw.
                    FieldFootage.keepCopy(of: url)
                    self.finishedClipURL = url
                } else if !FieldFootage.rescue(url) {
                    // Flow torn down mid-recording, or the file is unusable:
                    // nobody will claim it.
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        movieOutput.startRecording(to: url, recordingDelegate: recordingDelegate)
        isRecording = true
        recordingStartedAt = .now
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    /// Clears the finished clip so the flow can return to the record step.
    func discardClip() {
        if let finishedClipURL, !FieldFootage.rescue(finishedClipURL) {
            try? FileManager.default.removeItem(at: finishedClipURL)
        }
        finishedClipURL = nil
    }

    private func isAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private nonisolated static func configure(
        session: AVCaptureSession, movieOutput: AVCaptureMovieFileOutput
    ) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // Video-only capture has no business touching the audio session;
        // left on, this pauses the user's music the moment the camera starts.
        session.automaticallyConfiguresApplicationAudioSession = false
        session.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { throw CameraError.setupFailed }
        session.addInput(input)

        guard session.canAddOutput(movieOutput) else { throw CameraError.setupFailed }
        session.addOutput(movieOutput)
    }

    /// 1080p60 when the hardware allows it: a thrown ball covers about a
    /// foot between 30 fps frames, so 60 halves the per-frame motion blur and
    /// doubles the tracker's samples. Fixed rate (min == max) keeps frame
    /// spacing uniform for the speed math. The 1080p preset often selects a
    /// 30-capped format even when a 60 fps sibling exists, so search the
    /// device's formats for one matching the preset's dimensions and pixel
    /// format — only the rate changes. No match keeps the default: capturing
    /// at the preset's rate beats not capturing.
    private nonisolated static func requestSixtyFPS(session: AVCaptureSession) {
        guard let device = session.inputs
            .compactMap({ ($0 as? AVCaptureDeviceInput)?.device })
            .first(where: { $0.hasMediaType(.video) })
        else { return }
        let supports60 = { (format: AVCaptureDevice.Format) in
            format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 60 }
        }
        let current = device.activeFormat
        var target: AVCaptureDevice.Format? = supports60(current) ? current : nil
        if target == nil {
            let dims = CMVideoFormatDescriptionGetDimensions(current.formatDescription)
            let subType = CMFormatDescriptionGetMediaSubType(current.formatDescription)
            target = device.formats.first { format in
                let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return d.width == dims.width && d.height == dims.height
                    && CMFormatDescriptionGetMediaSubType(format.formatDescription) == subType
                    && supports60(format)
            }
        }
        guard let target else { return }
        do {
            try device.lockForConfiguration()
            if target !== current { device.activeFormat = target }
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            device.unlockForConfiguration()
        } catch {}
    }

    private enum CameraError: Error {
        case setupFailed
    }
}

/// AVCaptureFileOutputRecordingDelegate requires NSObject; kept separate so
/// CameraModel can stay a plain @Observable class.
private final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var onFinish: ((URL, Error?) -> Void)?

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        onFinish?(outputFileURL, error)
    }
}
