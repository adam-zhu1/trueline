import SwiftData
import SwiftUI

/// App preferences. Minimal for now; grows with the analysis pipeline.
struct SettingsView: View {
    @AppStorage("bowlingHand") private var bowlingHand = "right"
    @AppStorage("speedUnit") private var speedUnit = "mph"
    @AppStorage("saveShotVideos") private var saveShotVideos = true
    @Environment(\.modelContext) private var modelContext
    @State private var showHowItWorks = false
    @State private var videoBytes: Int64 = 0
    @State private var confirmDeleteVideos = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Bowler") {
                    Picker("Hand", selection: $bowlingHand) {
                        Text("Right").tag("right")
                        Text("Left").tag("left")
                    }
                }
                Section("Units") {
                    Picker("Ball speed", selection: $speedUnit) {
                        Text("mph").tag("mph")
                        Text("km/h").tag("kmh")
                    }
                }
                Section {
                    Toggle("Save video with each shot", isOn: $saveShotVideos)
                    LabeledContent(
                        "Video storage",
                        value: ByteCountFormatter.string(fromByteCount: videoBytes, countStyle: .file)
                    )
                    Button("Delete All Shot Videos", role: .destructive) {
                        confirmDeleteVideos = true
                    }
                    .disabled(videoBytes == 0)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Metrics and lane views are always kept — deleting videos only removes the replays.")
                }
                Section {
                    Button("How TrueLine works") { showHowItWorks = true }
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showHowItWorks) {
                OnboardingView { showHowItWorks = false }
            }
            .confirmationDialog(
                "Delete all shot videos?",
                isPresented: $confirmDeleteVideos,
                titleVisibility: .visible
            ) {
                Button("Delete All Videos", role: .destructive) { deleteAllVideos() }
            } message: {
                Text("Shot metrics and lane views are kept.")
            }
            .onAppear { videoBytes = ShotVideoStore.totalBytes() }
        }
    }

    private func deleteAllVideos() {
        ShotVideoStore.deleteAll()
        // Clear the dangling references so shot detail doesn't offer replays.
        let shots = (try? modelContext.fetch(FetchDescriptor<SavedShot>())) ?? []
        for shot in shots {
            shot.videoFileName = nil
        }
        videoBytes = 0
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: SavedShot.self, inMemory: true)
}
