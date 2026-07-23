import SwiftUI

/// Branded cold start, Adam's sequence: the wordmark pops up on black; a
/// bowling ball rolls straight up the center of the screen (no hook — the
/// brand doesn't pick a hand) and the wordmark splits to let it in; at dead
/// center the ball inflates until it floods the screen solid mint; the
/// wordmark returns near-black in the same spot; then the mint wipes up like
/// the curtain and Home lands underneath. ~3.7s, tap to skip, no artificial
/// loading — the app behind it is already ready. Reduce Motion gets a static
/// wordmark and a fade.
struct LaunchAnimationView: View {
    /// Fires when the curtain starts to lift (or on skip) — Home uses it to
    /// start landing its elements while the mint is still rising.
    var onReveal: () -> Void = {}
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    // The flood/wipe runs on Core Animation (state + withAnimation), not the
    // per-frame timeline — driving the offset from TimelineView recomputed
    // the whole layer every frame and dropped frames mid-wipe.
    @State private var floodShown = false
    @State private var logoIn = false
    @State private var wiped = false
    @State private var revealed = false
    @State private var finished = false

    // Timeline, seconds from start.
    private let wordIn = 0.15
    private let rollStart = 0.45
    private let rollEnd = 1.5
    private let growStart = 1.6
    private let growEnd = 2.05
    private let logoAt = 2.1
    // The inverted-logo hold is the brand beat — long enough to register,
    // short enough that the whole launch stays under four seconds.
    private let wipeAt = 3.25
    private let wipeDuration = 0.75

    private let inkDark = Color(red: 4 / 255, green: 19 / 255, blue: 12 / 255)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if reduceMotion {
                    ZStack {
                        Color.black
                        wordmark(gap: 0, dark: false)
                    }
                } else if !floodShown {
                    // Roll + split + inflate: per-frame canvas territory.
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSince(startDate)
                        scene(t: t, size: geo.size)
                    }
                }

                // The flood is its own layer so the wipe is a single
                // Core-Animation offset — no per-frame recomputation.
                if floodShown {
                    ZStack {
                        Color.brandMint
                        wordmark(gap: 0, dark: true)
                            .opacity(logoIn ? 1 : 0)
                            .scaleEffect(logoIn ? 1 : 0.96)
                    }
                    .compositingGroup()
                    .offset(y: wiped ? -geo.size.height * 1.15 : 0)
                }
            }
        }
        // Safe area escaped at the reader, not inside it, so geo.size is the
        // FULL screen — the curtain's travel is computed from it, and a
        // safe-area-height travel left a mint strip at the dynamic island.
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            if reduceMotion {
                try? await Task.sleep(for: .seconds(0.6))
                finish()
            } else {
                try? await Task.sleep(for: .seconds(logoAt))
                floodShown = true
                withAnimation(.easeOut(duration: 0.35)) { logoIn = true }
                try? await Task.sleep(for: .seconds(wipeAt - logoAt))
                reveal()
                withAnimation(.timingCurve(0.75, 0, 0.2, 1, duration: wipeDuration)) {
                    wiped = true
                }
                try? await Task.sleep(for: .seconds(wipeDuration + 0.1))
                finish()
            }
        }
    }

    // MARK: Scene

    @ViewBuilder
    private func scene(t: Double, size: CGSize) -> some View {
        let u = expoInOut((t - rollStart) / (rollEnd - rollStart))
        let travel = size.height / 2 + 60
        let dy = travel * (1 - u)
        let g = easeIn((t - growStart) / (growEnd - growStart))
        // Split opens as the ball closes in on the wordmark's center.
        let gap = 30 * smooth(min(max(1 - dy / 170, 0), 1))

        ZStack {
            Color.black
            wordmark(gap: gap, dark: false)
                .opacity(min(max((t - wordIn) / 0.35, 0), 1))

            // The ball: straight up the middle, then the inflation. Sized to
            // out-cover the screen diagonal at full scale. The mint flood
            // layer (in body) takes over at logoAt.
            if t >= rollStart {
                // Rolling, not spinning: rotation is distance over radius,
                // so the holes turn exactly as fast as the ball moves.
                ball(rotation: u * travel / 15, holeAlpha: 1 - min(g * 3, 1))
                    .scaleEffect(1 + g * (size.height * 1.4 / 30))
                    .offset(y: dy)
            }
        }
    }

    private func wordmark(gap: CGFloat, dark: Bool) -> some View {
        HStack(spacing: 0) {
            Text("True")
                .foregroundStyle(dark ? inkDark : .white)
                .offset(x: -gap)
            Text("Line")
                .foregroundStyle(dark ? inkDark : Color.brandMint)
                .offset(x: gap)
        }
        .font(.system(size: 42, weight: .bold))
    }

    private func ball(rotation: Double, holeAlpha: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.brandMint)
            // Finger holes, turning at rolling speed — what makes it a
            // bowling ball and not a dot.
            ZStack {
                Circle().frame(width: 5.5, height: 5.5).offset(x: -2, y: -6.5)
                Circle().frame(width: 5.5, height: 5.5).offset(x: -6.5, y: 0.5)
                Circle().frame(width: 5.5, height: 5.5).offset(x: 1.5, y: 1.5)
            }
            .foregroundStyle(.black.opacity(0.55 * holeAlpha))
            .rotationEffect(.radians(rotation))
        }
        .frame(width: 30, height: 30)
    }

    // MARK: Easing

    private func smooth(_ f: Double) -> Double {
        let c = min(max(f, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private func easeIn(_ f: Double) -> Double {
        let c = min(max(f, 0), 1)
        return c * c
    }

    /// Exponential ease in-out: near-still off the line, fast through the
    /// middle, hard deceleration into the arrival. Much sharper S than
    /// smoothstep — the ball's travel reads as a throw, not a tween.
    private func expoInOut(_ f: Double) -> Double {
        let c = min(max(f, 0), 1)
        if c == 0 || c == 1 { return c }
        return c < 0.5
            ? pow(2, 20 * c - 10) / 2
            : (2 - pow(2, 10 - 20 * c)) / 2
    }

    private func reveal() {
        guard !revealed else { return }
        revealed = true
        onReveal()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        reveal()
        onFinished()
    }
}

#Preview {
    ZStack {
        Color(white: 0.1).ignoresSafeArea()
        LaunchAnimationView {}
    }
}
