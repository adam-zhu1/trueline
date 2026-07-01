import SwiftUI

/// App preferences. Minimal for now; grows with the analysis pipeline.
struct SettingsView: View {
    @AppStorage("bowlingHand") private var bowlingHand = "right"
    @AppStorage("speedUnit") private var speedUnit = "mph"

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
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
