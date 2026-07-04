import CoreGraphics
import Foundation

/// The stylized right-hand hook shared by the brand animations (launch, analysis
/// progress): board 1–39 as a function of travel down the lane, 0 = foul line,
/// 1 = pins. Drifts out to a board-7 breakpoint at 74% of the lane, then turns
/// hard into the 17.5 pocket. Decoration, not data — real paths come from the
/// analyzer.
enum HookCurve {
    static let breakpoint = 0.72

    static func board(at u: Double) -> Double {
        let u = min(max(u, 0), 1)
        if u < breakpoint {
            // Skid phase: a real ball leaves the hand on a nearly straight
            // outward line and only flattens approaching the breakpoint —
            // the low exponent keeps this leg linear so it doesn't read as a
            // wiggle.
            let s = sin((u / breakpoint) * .pi / 2)
            return 17.0 - 10.0 * pow(s, 1.1)
        } else {
            // Hook phase: one decisive turn, steepest at the pins (that's
            // the entry angle).
            let s = (u - breakpoint) / (1 - breakpoint)
            return 7.0 + 10.5 * pow(s, 2.0)
        }
    }

    /// Point in `rect` for travel `u`, using the lane-view convention (board 1
    /// on the right edge, foul line at the bottom).
    static func point(at u: Double, in rect: CGRect) -> CGPoint {
        let t = (board(at: u) - 1) / 38.0
        return CGPoint(
            x: rect.minX + rect.width * (1.0 - t),
            y: rect.maxY - rect.height * min(max(u, 0), 1)
        )
    }
}
