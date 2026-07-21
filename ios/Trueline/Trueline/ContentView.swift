import SwiftData
import SwiftUI

/// What the full-screen capture overlay is showing.
enum CaptureRoute: Equatable {
    case record
    case imported(URL)
}

/// Root of the app: a three-tab shell. The capture sequence (record → calibrate →
/// analyze → results) renders as a ZStack overlay, NOT a fullScreenCover:
/// presenting a cover while another presentation (the Photos picker sheet, the
/// first-run onboarding cover) is still mid-dismissal can wedge half-presented,
/// leaving the home screen and the flow visible at once. An overlay has no
/// UIKit presentation machinery to wedge.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    /// "dark" (default, the brand look), "light", or "system". Cinema
    /// surfaces (capture, analysis, launch) hardcode dark regardless.
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.modelContext) private var modelContext
    @State private var showOnboarding = false
    @State private var capture: CaptureRoute?
    /// Cold-start brand moment; once per process.
    @State private var showLaunch = true
    /// Flips when the launch curtain starts to lift — Home lands its
    /// elements against it.
    @State private var homeRevealed = false

    var body: some View {
        ZStack {
            TabView {
                BowlHomeView(capture: $capture, entrance: homeRevealed)
                    .tabItem { Label("Bowl", systemImage: "figure.bowling") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }

            if let capture {
                captureFlow(for: capture)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }

            if showLaunch {
                LaunchAnimationView(
                    onReveal: { homeRevealed = true },
                    onFinished: { finishLaunch() }
                )
                .zIndex(2)
            }
        }
        // Brand default is mint-on-dark, but appearance is a Settings choice
        // now. nil hands the decision to the system.
        .preferredColorScheme(
            appearance == "dark" ? .dark : appearance == "light" ? .light : nil
        )
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .task {
            #if DEBUG
            DemoSeed.seedIfRequested(context: modelContext)
            #endif
            // Orphan sweep: drop replay files no shot references (crash
            // between file move and model save, failed delete, etc.).
            let names = ((try? modelContext.fetch(FetchDescriptor<SavedShot>())) ?? [])
                .compactMap(\.videoFileName)
            let keep = Set(names)
            Task.detached(priority: .background) {
                ShotVideoStore.sweepOrphans(keeping: keep)
            }
        }
    }

    /// First-run onboarding waits for the launch animation — presenting a
    /// cover over the fading overlay looks broken and buries the brand moment.
    /// The launch view has already wiped itself off-screen by now; the short
    /// fade only matters for tap-to-skip.
    private func finishLaunch() {
        homeRevealed = true
        withAnimation(.easeOut(duration: 0.25)) { showLaunch = false }
        if !hasSeenOnboarding { showOnboarding = true }
    }

    @ViewBuilder
    private func captureFlow(for route: CaptureRoute) -> some View {
        let exit = {
            withAnimation(.easeInOut(duration: 0.25)) { capture = nil }
        }
        switch route {
        case .record:
            CaptureFlowView(onExit: exit)
        case .imported(let url):
            CaptureFlowView(importedClipURL: url, onExit: exit)
        }
    }
}

#Preview {
    ContentView()
        .environment(TruelineStore())
}
