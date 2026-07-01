import SwiftUI

/// Root of the app: a three-tab shell. The capture sequence (record → calibrate →
/// analyze → results) is presented full-screen from the Bowl tab.
struct ContentView: View {
    var body: some View {
        TabView {
            BowlHomeView()
                .tabItem { Label("Bowl", systemImage: "figure.bowling") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
}
