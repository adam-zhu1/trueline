import SwiftUI

/// Branded cold start, Adam's strike (design locked in the Trueline Claude
/// Design project): the wordmark pops up on black; a bowling ball accelerates
/// straight up the center — flat-out at contact, never braking — and the
/// letters explode off the screen like struck pins; after a short fall beat
/// the ball inflates until it floods the screen solid mint; the wordmark
/// returns near-black, intact and calm; then the mint wipes up like the
/// curtain and Home lands underneath. ~4.4s, tap to skip, no artificial
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

    // Timeline, seconds from start. Three beats after the roll: contact
    // explodes the text, a short fall lets the letters read, then the ball
    // expands. Timings approved on the design-project mock.
    private let wordIn = 0.15
    private let rollStart = 0.5
    private let impact = 1.35
    private let growStart = 1.75
    private let growEnd = 2.2
    private let logoAt = 2.25
    private let wipeAt = 3.6
    private let wipeDuration = 0.75

    private let inkDark = Color(red: 4 / 255, green: 19 / 255, blue: 12 / 255)

    /// The wordmark, letter by letter, with each letter's strike kick:
    /// launched away from center on contact, up first, then gravity, each
    /// with its own tumble. Deterministic — the same perfect strike every
    /// launch, tuned like keyframes.
    private static let letters: [(char: String, mint: Bool)] = [
        ("T", false), ("r", false), ("u", false), ("e", false),
        ("L", true), ("i", true), ("n", true), ("e", true),
    ]
    private static let kicks: [(vx: Double, vy: Double, spin: Double)] = [
        (-300, -260, -6.5), (-210, -350, -5), (-140, -300, -8), (-70, -430, -4),
        (80, -420, 5), (150, -310, 7.5), (230, -360, 4.5), (320, -270, 8),
    ]
    private static let gravity = 1500.0

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
        // Accelerating the whole way — a strike arrives at full speed;
        // easing out here is what made the hit feel laggy.
        let u = expoIn((t - rollStart) / (impact - rollStart))
        let travel = size.height / 2 + 60
        let dy = travel * (1 - u)
        let g = easeIn((t - growStart) / (growEnd - growStart))

        ZStack {
            Color.black
            strikeWordmark(t: t)
                .opacity(min(max((t - wordIn) / 0.35, 0), 1))

            // The ball: dead stop on contact, holds through the fall beat,
            // then the inflation. Sized to out-cover the screen diagonal at
            // full scale. The mint flood layer (in body) takes over at logoAt.
            if t >= rollStart {
                // Rolling, not spinning: rotation is distance over radius,
                // so the holes turn exactly as fast as the ball moves.
                ball(rotation: u * travel / 15, holeAlpha: 1 - min(g * 3, 1))
                    .scaleEffect(1 + g * (size.height * 1.4 / 30))
                    .offset(y: dy)
            }
        }
    }

    /// The wordmark as eight letters; from the moment of impact each flies
    /// on its kick — a tiny ripple delay spreads from the center letters out.
    private func strikeWordmark(t: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(Self.letters.indices, id: \.self) { i in
                let letter = Self.letters[i]
                let kick = Self.kicks[i]
                let delay = abs(Double(i) - 3.5) * 0.028
                let s = max(0, t - impact - delay)
                Text(letter.char)
                    .foregroundStyle(letter.mint ? Color.brandMint : .white)
                    .offset(
                        x: kick.vx * s,
                        y: kick.vy * s + 0.5 * Self.gravity * s * s
                    )
                    .rotationEffect(.radians(kick.spin * s))
            }
        }
        .font(.system(size: 42, weight: .bold))
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

    /// Pure exponential ease-in: near-still off the line, flat-out at impact.
    private func expoIn(_ f: Double) -> Double {
        let c = min(max(f, 0), 1)
        return c == 0 ? 0 : pow(2, 10 * c - 10)
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
