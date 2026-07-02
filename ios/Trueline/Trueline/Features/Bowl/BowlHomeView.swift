import PhotosUI
import SwiftUI

/// The primary tab: an entry point that launches the capture flow, either from a
/// live recording or an existing video (useful without lane access).
struct BowlHomeView: View {
    /// One presentation path for both entry points — two fullScreenCover
    /// modifiers racing the Photos picker's dismissal can end up half-presented
    /// with the home screen showing through.
    private enum CapturePresentation: Identifiable {
        case record
        case imported(URL)

        var id: String {
            switch self {
            case .record: "record"
            case .imported(let url): url.absoluteString
            }
        }
    }

    @State private var presentation: CapturePresentation?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.bowling")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("TrueLine")
                    .font(.largeTitle.bold())
                Text("Record a throw to get your line, speed, breakpoint, and entry angle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    presentation = .record
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
            .fullScreenCover(item: $presentation) { presentation in
                switch presentation {
                case .record:
                    CaptureFlowView()
                case .imported(let url):
                    CaptureFlowView(importedClipURL: url)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                isImporting = true
                Task {
                    let file = try? await item.loadTransferable(type: VideoFile.self)
                    pickerItem = nil
                    // Let the picker sheet finish dismissing before presenting
                    // the cover, or the presentation can break mid-flight.
                    try? await Task.sleep(for: .milliseconds(450))
                    isImporting = false
                    if let file {
                        self.presentation = .imported(file.url)
                    }
                }
            }
        }
    }
}

#Preview {
    BowlHomeView()
}
