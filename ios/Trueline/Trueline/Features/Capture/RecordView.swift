import SwiftUI

/// The record step: live preview with a lane-framing guide, a record/stop button,
/// and an elapsed timer while recording.
struct RecordView: View {
    var camera: CameraModel
    /// Target-line practice: the board the bowler is aiming over at the
    /// arrows, shared with the capture flow so results can score the miss.
    @Binding var targetBoard: Double?
    var onCancel: () -> Void

    @State private var showTargetPicker = false

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
                    .buttonStyle(.primaryAction)
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
                    } else if camera.status == .previewing {
                        Button {
                            showTargetPicker = true
                        } label: {
                            Label(
                                targetBoard.map { "Target \(Int($0))" } ?? "Set Target",
                                systemImage: "scope"
                            )
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.5), in: Capsule())
                            .foregroundStyle(targetBoard == nil ? .white : Color.brandMint)
                        }
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
        .sheet(isPresented: $showTargetPicker) {
            TargetPickerSheet(targetBoard: $targetBoard)
                .presentationDetents([.height(320)])
        }
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

/// Wheel picker for the target board at the arrows (hand-normalized: board 1
/// is the outside board, 20 the center arrow).
private struct TargetPickerSheet: View {
    @Binding var targetBoard: Double?

    @Environment(\.dismiss) private var dismiss
    @State private var board = 17

    var body: some View {
        VStack(spacing: 8) {
            Text("Target board at the arrows")
                .font(.headline)
                .padding(.top, 20)
            Text("Every throw gets scored against it — aim over one board all session.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Picker("Target board", selection: $board) {
                ForEach(1...39, id: \.self) { b in
                    Text("Board \(b)").tag(b)
                }
            }
            .pickerStyle(.wheel)
            HStack(spacing: 12) {
                if targetBoard != nil {
                    Button("Clear") {
                        targetBoard = nil
                        dismiss()
                    }
                    .buttonStyle(.secondaryAction)
                }
                Button("Set Target") {
                    targetBoard = Double(board)
                    dismiss()
                }
                .buttonStyle(.primaryAction)
            }
            .padding([.horizontal, .bottom])
        }
        .onAppear {
            if let targetBoard {
                board = Int(targetBoard)
            }
        }
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
