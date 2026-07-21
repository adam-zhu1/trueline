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
            if reduceMotion {
                ZStack {
                    Color.black.ignoresSafeArea()
                    wordmark(gap: 0, dark: false)
                }
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSince(startDate)
                    scene(t: t, size: geo.size)
                }
                .ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            if reduceMotion {
                try? await Task.sleep(for: .seconds(0.6))
                finish()
            } else {
                try? await Task.sleep(for: .seconds(wipeAt))
                reveal()
                try? await Task.sleep(for: .seconds(wipeDuration + 0.1))
                finish()
            }
        }
    }

    // MARK: Scene

    @ViewBuilder
    private func scene(t: Double, size: CGSize) -> some View {
        let u = smooth((t - rollStart) / (rollEnd - rollStart))
        let dy = (size.height / 2 + 60) * (1 - u)
        let g = easeIn((t - growStart) / (growEnd - growStart))
        // Split opens as the ball closes in on the wordmark's center.
        let gap = 30 * smooth(min(max(1 - dy / 170, 0), 1))
        let wipe = wipeProgress(t)

        ZStack {
            // Black stage with the splitting wordmark; gone once the flood
            // owns the screen.
            if t < logoAt {
                Color.black
                wordmark(gap: gap, dark: false)
                    .opacity(min(max((t - wordIn) / 0.35, 0), 1))
            }

            // The ball: straight up the middle, then the inflation. Sized to
            // out-cover the screen diagonal at full scale.
            if t >= rollStart, t < logoAt {
                ball(rotation: u * 56, holeAlpha: 1 - min(g * 3, 1))
                    .scaleEffect(1 + g * (size.height * 1.4 / 30))
                    .offset(y: dy)
            }

            // The flood: solid mint, the wordmark back in near-black at the
            // same spot. The whole layer is the curtain — it wipes up to
            // reveal Home already landing beneath.
            if t >= logoAt {
                ZStack {
                    Color.brandMint
                    wordmark(gap: 0, dark: true)
                        .opacity(min(max((t - logoAt) / 0.3, 0), 1))
                        .scaleEffect(0.96 + 0.04 * smooth((t - logoAt) / 0.45))
                }
                .compositingGroup()
                .offset(y: -size.height * 1.05 * wipe)
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
                Circle().frame(width: 4.5, height: 4.5).offset(x: -2, y: -6)
                Circle().frame(width: 4.5, height: 4.5).offset(x: -6, y: 0)
                Circle().frame(width: 4.5, height: 4.5).offset(x: 1, y: 1)
            }
            .foregroundStyle(.black.opacity(0.45 * holeAlpha))
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

    /// Double smoothstep: a sharper S than plain smoothstep, close to the
    /// curtain's cubic-bezier feel.
    private func wipeProgress(_ t: Double) -> CGFloat {
        let p = smooth((t - wipeAt) / wipeDuration)
        return CGFloat(smooth(p))
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
