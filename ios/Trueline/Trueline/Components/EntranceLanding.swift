import SwiftUI

/// One element of an entrance choreography: hidden below its resting place
/// until `shown`, then it rises and fades in on a small spring, each index a
/// beat later than the last. Inert when `active` is false, so the same view
/// can render statically (History, previews) or choreographed (fresh result,
/// cold-start Home).
struct EntranceLanding: ViewModifier {
    var active: Bool
    var shown: Bool
    var index: Int
    var reduceMotion: Bool
    /// Delay before the first element lands; siblings follow every `step`.
    var baseDelay: Double = 1.0
    var step: Double = 0.07

    func body(content: Content) -> some View {
        content
            .opacity(!active || shown ? 1 : 0)
            .offset(y: !active || shown || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion
                    ? .easeIn(duration: 0.3).delay(baseDelay * 0.4)
                    : .spring(response: 0.45, dampingFraction: 0.8)
                        .delay(baseDelay + Double(index) * step),
                value: shown
            )
    }
}
