import SwiftUI

/// Shared button system: one primary and one secondary treatment across every
/// screen, so the flow reads as one product instead of per-screen styling.
/// Full-width, fixed-height, high-contrast fill — the primary action on a
/// screen is always the mint bar. Black on bright mint reads 13:1 in either
/// appearance, so the primary bar is the same in light and dark; the
/// secondary treatments use the adaptive ink and fill tokens.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            // A floor, not a fixed height: at the accessibility text sizes
            // the label wraps and the bar grows instead of clipping.
            .frame(minHeight: 54)
            .background(Color.brandMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.4))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.inkPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            // A floor, not a fixed height: at the accessibility text sizes
            // the label wraps and the bar grows instead of clipping.
            .frame(minHeight: 54)
            .background(Color.controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.4))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondaryAction: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Icon-only square in the secondary treatment, for rows where the primary
/// bar needs the width (calibration's Back/Reset beside "Looks Good"). Give
/// these an accessibilityLabel — the icon is all VoiceOver gets otherwise.
struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.inkPrimary)
            .frame(width: 54, height: 54)
            .background(Color.controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.4))
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var iconAction: IconButtonStyle { IconButtonStyle() }
}

/// Quiet text action under the primary bar (Restore Purchases on the
/// paywall): footnote size in the accent mint, at least 44 pt tall.
struct TextActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundStyle(Color.accentMint)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : (isEnabled ? 1 : 0.5))
    }
}

extension ButtonStyle where Self == TextActionButtonStyle {
    static var textAction: TextActionButtonStyle { TextActionButtonStyle() }
}
