import SwiftUI
import UIKit

/// TrueLine brand palette — mint on dark (chosen over the prototype's orange).
///
/// Two kinds of color live here. The fixed brand colors (`brandMint`,
/// `brandMintDim`) are for surfaces that are dark in every appearance: the
/// camera, the lane diagrams, the video overlays, the primary button fill.
/// The adaptive tokens below are for content screens that follow the
/// Appearance setting. Each one resolves to the exact value the dark look
/// has always used, so dark mode is unchanged; the light values are tuned
/// for contrast on white.
extension Color {
    /// Primary accent: ball path, markers, highlights. Fixed bright mint, for
    /// dark surfaces and fills only (1.6:1 on white, so never text on light).
    static let brandMint = Color(red: 0.25, green: 0.90, blue: 0.62)
    /// Muted accent: guides, arrow V, reference lines.
    static let brandMintDim = Color(red: 0.16, green: 0.58, blue: 0.42)

    /// Mint for text, icons, and chart marks on content backgrounds. Dark:
    /// the brand mint. Light: a deep mint, #007A50, 5.4:1 on white and 4.8:1
    /// on the grouped gray, so it clears WCAG AA for body text on both.
    static let accentMint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.90, blue: 0.62, alpha: 1)
            : UIColor(red: 0, green: 122 / 255, blue: 80 / 255, alpha: 1)
    })

    /// Text ink at a given emphasis. Dark resolves to white at exactly
    /// `opacity` (the original hand-tuned values); light uses black a step
    /// stronger, because gray-on-white loses contrast faster than
    /// gray-on-black (0.4 maps to 0.6, about 5.7:1 on white).
    static func ink(_ opacity: Double) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: opacity)
                : UIColor(white: 0, alpha: min(1, opacity + 0.2))
        })
    }

    /// Full-strength text: white on dark, black on light.
    static let inkPrimary = ink(1)
    /// Units and supporting numbers.
    static let inkSecondary = ink(0.45)
    /// Small caps labels and captions.
    static let inkTertiary = ink(0.4)

    /// Fill behind secondary and icon buttons: translucent white on dark, a
    /// neutral gray on light (close to the system's tertiary fill, a touch
    /// stronger so the button edge reads on white).
    static let controlFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(red: 118 / 255, green: 118 / 255, blue: 128 / 255, alpha: 0.16)
    })

    /// Page background for card layouts (Stats, shot results): black on dark,
    /// the grouped gray on light so white cards stand off it.
    static let pageBackground = Color(uiColor: .systemGroupedBackground)

    /// Hairline separators and card outlines.
    static let hairline = Color(uiColor: .separator)
}

/// Card surface for tiles and dashboard cards. Dark keeps the original
/// translucent quaternary fill; light uses the grouped-content white, which
/// sits on `Color.pageBackground` the way Health and Fitness cards do.
struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(
            colorScheme == .dark
                ? AnyShapeStyle(.quaternary.opacity(0.4))
                : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)),
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 12) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}
