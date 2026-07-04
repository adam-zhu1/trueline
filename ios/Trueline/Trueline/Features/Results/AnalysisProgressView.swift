import SwiftUI

/// Determinate, bowling-shaped progress for the analysis step: the hook path
/// is the progress bar — a dim track shows the full line ahead, the traveled
/// portion lights up in mint as the clip is processed, matching the launch
/// animation's language. Driven by real analysis progress, never fake motion;
/// a percentage backs it up because a full clip can take a while on device.
struct AnalysisProgressView: View {
    /// Real progress, 0–1.
    var progress: Double

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                // The road ahead, barely there.
                HookTrailShape(progress: 1)
                    .stroke(
                        Color.white.opacity(0.10),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                // Target ring at the pocket.
                Circle()
                    .stroke(Color.brandMintDim, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                    .position(pocketPosition)
                HookTrailShape(progress: progress)
                    .stroke(
                        Color.brandMint,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                HookBallShape(progress: progress)
                    .fill(Color.brandMint)
                    .shadow(color: Color.brandMint.opacity(0.7), radius: 7)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .animation(.linear(duration: 0.3), value: progress)

            VStack(spacing: 6) {
                Text("Tracking the ball…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(progress > 0 ? "\(Int((progress * 100).rounded()))%" : " ")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canvasSize: CGSize { CGSize(width: 140, height: 260) }

    private var pocketPosition: CGPoint {
        HookCurve.point(at: 1, in: drawRect(in: CGRect(origin: .zero, size: canvasSize)))
    }
}

/// Drawing area shared by the track, trail, and ball so they align exactly.
private func drawRect(in rect: CGRect) -> CGRect {
    rect.insetBy(dx: 10, dy: 10)
}

private struct HookTrailShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let area = drawRect(in: rect)
        var path = Path()
        let end = min(max(progress, 0), 1)
        guard end > 0 else { return path }
        let steps = max(2, Int(end * 60))
        for i in 0...steps {
            let u = end * Double(i) / Double(steps)
            let pt = HookCurve.point(at: u, in: area)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

private struct HookBallShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let pt = HookCurve.point(at: min(max(progress, 0), 1), in: drawRect(in: rect))
        let r: CGFloat = 6
        return Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnalysisProgressView(progress: 0.62)
    }
}
