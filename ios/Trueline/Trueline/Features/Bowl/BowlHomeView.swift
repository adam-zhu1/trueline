import PhotosUI
import SwiftUI

/// The primary tab: an entry point that launches the capture flow, either from a
/// live recording or an existing video (useful without lane access).
struct BowlHomeView: View {
    @State private var showCapture = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var importedClip: ImportedClip?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.bowling")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("Trueline")
                    .font(.largeTitle.bold())
                Text("Record a throw to get your line, speed, breakpoint, and entry angle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    showCapture = true
                } label: {
                    Label("Start Session", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Label(
                        isImporting ? "Importing…" : "Analyze Existing Video",
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isImporting)
            }
            .padding()
            .navigationTitle("Bowl")
            .fullScreenCover(isPresented: $showCapture) {
                CaptureFlowView()
            }
            .fullScreenCover(item: $importedClip) { clip in
                CaptureFlowView(importedClipURL: clip.url)
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                isImporting = true
                Task {
                    if let file = try? await item.loadTransferable(type: VideoFile.self) {
                        importedClip = ImportedClip(url: file.url)
                    }
                    pickerItem = nil
                    isImporting = false
                }
            }
        }
    }
}

#Preview {
    BowlHomeView()
}
