import PhotosUI
import SwiftUI

/// The primary tab: an entry point that launches the capture flow, either from a
/// live recording or an existing video (useful without lane access).
struct BowlHomeView: View {
    /// Owned by ContentView, which renders the capture flow as a root overlay.
    @Binding var capture: CaptureRoute?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importFailed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.bowling")
                        .font(.title3)
                        .foregroundStyle(Color.brandMint)
                    Text("TrueLine")
                        .font(.headline)
                }
                .padding(.top, 8)

                Text("Every throw,\nmeasured.")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.top, 28)

                Text("Prop your phone behind the approach and bowl. Speed, line, breakpoint, and entry angle for every shot.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        present(.record)
                    } label: {
                        Label("Start Session", systemImage: "record.circle.fill")
                    }
                    .buttonStyle(.primaryAction)

                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label(
                            isImporting ? "Importing…" : "Analyze Existing Video",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(.secondaryAction)
                    .disabled(isImporting)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                isImporting = true
                Task {
                    let file = try? await item.loadTransferable(type: VideoFile.self)
                    pickerItem = nil
                    isImporting = false
                    // The overlay can appear while the picker sheet is still
                    // animating away — the sheet just slides off to reveal it.
                    // No presentation to race, so no grace timer.
                    if let file {
                        present(.imported(file.url))
                    } else {
                        // Silent failure reads as a broken button.
                        importFailed = true
                    }
                }
            }
            .alert("Couldn't load that video", isPresented: $importFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a different video — it may still be downloading from iCloud.")
            }
        }
    }

    private func present(_ route: CaptureRoute) {
        withAnimation(.easeInOut(duration: 0.25)) { capture = route }
    }
}

#Preview {
    BowlHomeView(capture: .constant(nil))
}
