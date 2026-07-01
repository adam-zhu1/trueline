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
    private(set) var recordingStartedAt: Date?
    /// Set when a recording finishes successfully; observed by the capture flow.
    private(set) var finishedClipURL: URL?

    func start() async {
        guard status == .idle else { return }
        guard await isAuthorized() else {
            status = .denied
            return
        }
        do {
            try configureSession()
        } catch {
            status = .failed
            return
        }
        let session = session
        await Task.detached(priority: .userInitiated) {
            session.startRunning()
        }.value
        status = .previewing
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
                guard let self else { return }
                self.isRecording = false
                self.recordingStartedAt = nil
                if error == nil { self.finishedClipURL = url }
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
        if let finishedClipURL {
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

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { throw CameraError.setupFailed }
        session.addInput(input)

        guard session.canAddOutput(movieOutput) else { throw CameraError.setupFailed }
        session.addOutput(movieOutput)
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
