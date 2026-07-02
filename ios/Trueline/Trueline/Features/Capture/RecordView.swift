import SwiftUI

/// The record step: live preview with a lane-framing guide, a record/stop button,
/// and an elapsed timer while recording.
struct RecordView: View {
    var camera: CameraModel
    var onCancel: () -> Void

    var body: some View {
        // Camera starts here (not in the flow) so an imported-video session
        // never triggers the permission prompt.
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.status {
            case .previewing:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            case .denied:
                statusMessage(
                    icon: "video.slash",
                    title: "Camera access needed",
                    detail: "Allow camera access in Settings to record your throws."
                ) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .failed:
                statusMessage(
                    icon: "exclamationmark.triangle",
                    title: "Camera unavailable",
                    detail: "Couldn't start the camera on this device."
                ) { EmptyView() }
            case .idle:
                ProgressView()
                    .tint(.white)
            }

            VStack {
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if camera.isRecording, let start = camera.recordingStartedAt {
                        Text(start, style: .timer)
                            .font(.headline.monospacedDigit())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.red, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding()

                Spacer()

                if camera.status == .previewing {
                    VStack(spacing: 16) {
                        if !camera.isRecording {
                            Text("Aim the camera down the lane, record, and bowl.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.5), in: Capsule())
                        }
                        RecordButton(isRecording: camera.isRecording) {
                            if camera.isRecording {
                                camera.stopRecording()
                            } else {
                                camera.startRecording()
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .task { await camera.start() }
    }

    private func statusMessage(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder action: () -> some View
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            action()
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}

private struct RecordButton: View {
    var isRecording: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: isRecording ? 6 : 30)
                    .fill(.red)
                    .frame(
                        width: isRecording ? 32 : 60,
                        height: isRecording ? 32 : 60
                    )
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}
