import SwiftUI

@main
struct TruelineApp: App {
    var body: some Scene {
        WindowGroup {
            if let demoURL = Self.calibrationDemoURL {
                CalibrationView(clipURL: demoURL, onBack: {}, onConfirm: { _ in })
            } else {
                ContentView()
            }
        }
    }

    /// Debug hook: launch with `-calibrationDemo <path>` to jump straight to the
    /// calibration screen with a local clip — lets the simulator (no camera)
    /// exercise the corner-adjust UI.
    private static var calibrationDemoURL: URL? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "calibrationDemo")
            .map(URL.init(fileURLWithPath:))
        #else
        nil
        #endif
    }
}
