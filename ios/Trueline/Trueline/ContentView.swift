import StoreKit
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
    /// surfaces (capture, analysis, launch) stay dark regardless: their
    /// content pins the dark scheme, and the window follows once they cover
    /// the screen (see `windowScheme`).
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    /// The scheme the window currently resolves to. Only trusted as the
    /// system appearance while the window isn't overridden (see
    /// `systemScheme`).
    @Environment(\.colorScheme) private var resolvedScheme
    /// The system appearance, remembered from moments when the window
    /// follows it. While a cinema surface forces the window dark, the
    /// environment reads dark too, so this is what "System" means then.
    @State private var systemScheme: ColorScheme = .dark
    /// The capture flow's latest analysis produced a result (not a failed
    /// track). Gates the rating prompt on the way back to Home.
    @State private var lastAnalysisSucceeded = false
    @State private var showOnboarding = false
    @State private var showWhatsNew = false
    @State private var capture: CaptureRoute?
    /// Set when the capture flow exits via "Pick Another" — Home reopens the
    /// video picker so the re-pick is one tap shorter.
    @State private var repickAfterExit = false
    /// Cold-start brand moment; once per process.
    @State private var showLaunch = true
    /// Flips when the launch curtain starts to lift — Home lands its
    /// elements against it.
    @State private var homeRevealed = false
    /// The capture flow's current step is a cinema surface (everything but
    /// the shot result).
    @State private var captureIsCinema = false
    /// True once the capture overlay has finished sliding in, and until it
    /// has slid off the status bar on the way out. The window is dark only
    /// in between, so the status bar always matches the surface under it and
    /// Home never visibly changes appearance while the overlay moves.
    @State private var captureSettled = false
    /// Debug builds honor `-startTab <0-3>` so the simulator can open on any
    /// tab without taps (screenshots of both appearances).
    @State private var tab: Int = {
        #if DEBUG
        UserDefaults.standard.integer(forKey: "startTab")
        #else
        0
        #endif
    }()

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                BowlHomeView(capture: $capture, repick: $repickAfterExit, entrance: homeRevealed)
                    .tabItem { Label("Bowl", systemImage: "figure.bowling") }
                    .tag(0)
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    .tag(1)
                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(2)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(3)
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
                .environment(\.colorScheme, .dark)
                .zIndex(2)
            }
        }
        .preferredColorScheme(windowScheme)
        .onChange(of: resolvedScheme, initial: true) { _, scheme in
            if windowScheme == nil { systemScheme = scheme }
        }
        .task(id: capture != nil) {
            guard capture != nil else {
                // The overlay slides down over 0.25 s, so its top edge leaves
                // the status bar early; the window follows Home from then.
                try? await Task.sleep(for: .milliseconds(Self.overlayClearsStatusBarMs))
                guard !Task.isCancelled else { return }
                captureSettled = false
                return
            }
            lastAnalysisSucceeded = false
            // Matches the overlay's slide-in in present(_:).
            try? await Task.sleep(for: .milliseconds(260))
            captureSettled = true
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .fullScreenCover(isPresented: $showWhatsNew) {
            WhatsNewView { showWhatsNew = false }
        }
        .onChange(of: capture) { _, route in
            // Back on Home after a flow whose last throw produced a result:
            // the calm moment to ask for a rating. The delay lets the overlay
            // finish sliding away; whatever is up by then (a new capture, the
            // Photos picker, a cover) wins, and the ask waits for next time.
            guard route == nil, lastAnalysisSucceeded, !repickAfterExit else { return }
            Task {
                try? await Task.sleep(for: .seconds(1))
                guard ReviewPrompt.mayRequest(
                    afterSuccessfulResult: lastAnalysisSucceeded,
                    captureOpen: capture != nil,
                    somethingPresented: showOnboarding || showWhatsNew || Self.windowIsPresenting
                ), ReviewPrompt.consumeIfDue() else { return }
                requestReview()
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

    /// The window's scheme drives the status bar and UIKit chrome. Brand
    /// default is mint-on-dark, but appearance is a Settings choice; nil
    /// hands the decision to the system. Dark wins while the launch
    /// animation still covers Home and while a cinema step of the capture
    /// flow is on screen.
    private var windowScheme: ColorScheme? {
        if !homeRevealed || (captureSettled && captureIsCinema) {
            return .dark
        }
        return appearance == "dark" ? .dark : appearance == "light" ? .light : nil
    }

    /// The Appearance setting resolved to a concrete scheme, for capture
    /// steps that follow it while the window is still dark.
    private var appearanceScheme: ColorScheme {
        appearance == "dark" ? .dark : appearance == "light" ? .light : systemScheme
    }

    /// The exit slide is easeInOut over 0.25 s; the overlay's top edge is
    /// past the status bar (about 7% of the screen height) after ~50 ms.
    private static let overlayClearsStatusBarMs = 50

    /// True when anything (a sheet, a cover, the Photos picker) is presented
    /// over the root, including presentations Home owns.
    private static var windowIsPresenting: Bool {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        return root?.presentedViewController != nil
    }

    /// First-run onboarding waits for the launch animation — presenting a
    /// cover over the fading overlay looks broken and buries the brand moment.
    /// The launch view has already wiped itself off-screen by now; the short
    /// fade only matters for tap-to-skip.
    private func finishLaunch() {
        homeRevealed = true
        withAnimation(.easeOut(duration: 0.25)) { showLaunch = false }
        // Read before onboarding flips hasSeenOnboarding: a fresh install
        // gets onboarding only, an upgrade from 1.0 gets the update notes.
        let defaults = UserDefaults.standard
        let hasThrows = ((try? modelContext.fetchCount(FetchDescriptor<SavedShot>())) ?? 0) > 0
        let showNotes = WhatsNew.shouldShow(
            lastSeenVersion: defaults.string(forKey: WhatsNew.lastSeenVersionKey),
            hasUsedApp: hasSeenOnboarding || hasThrows,
            currentVersion: AppInfo.version
        )
        defaults.set(AppInfo.version, forKey: WhatsNew.lastSeenVersionKey)
        if !hasSeenOnboarding {
            showOnboarding = true
        } else if showNotes {
            showWhatsNew = true
        }
        #if DEBUG
        // `-captureImport <path>` opens the capture flow on a local clip, as
        // if picked from Photos, so the cinema screens can be checked in the
        // simulator without taps.
        if let path = UserDefaults.standard.string(forKey: "captureImport") {
            withAnimation(.easeInOut(duration: 0.25)) {
                capture = .imported(URL(fileURLWithPath: path))
            }
        }
        #endif
    }

    @ViewBuilder
    private func captureFlow(for route: CaptureRoute) -> some View {
        let exit = {
            withAnimation(.easeInOut(duration: 0.25)) { capture = nil }
        }
        switch route {
        case .record:
            CaptureFlowView(
                onExit: exit,
                onCinemaChange: { captureIsCinema = $0 },
                onAnalysisOutcome: { lastAnalysisSucceeded = $0 },
                contentScheme: appearanceScheme
            )
        case .imported(let url):
            CaptureFlowView(
                importedClipURL: url,
                onExit: exit,
                onRepick: {
                    exit()
                    repickAfterExit = true
                },
                onCinemaChange: { captureIsCinema = $0 },
                onAnalysisOutcome: { lastAnalysisSucceeded = $0 },
                contentScheme: appearanceScheme
            )
        }
    }
}

#Preview {
    ContentView()
        .environment(TruelineStore())
}
