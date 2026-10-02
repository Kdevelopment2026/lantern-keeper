import SwiftUI

extension Color {
    /// sRGB colour from a 24-bit hex value, for design tokens only.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Raw colour tokens. Feature views use `Theme` instead.
enum Palette {
    static let night = Color(hex: 0x06141D)
    static let deepSea = Color(hex: 0x0A2630)
    static let horizon = Color(hex: 0x244651)
    static let moon = Color(hex: 0xDCE7E9)
    static let mist = Color(hex: 0x91A8AD)
    static let lantern = Color(hex: 0xF3C969)
    static let dawn = Color(hex: 0xE79A72)
    static let ink = Color(hex: 0x10232A)
}

/// Semantic colours for one palette and contrast setting.
struct Theme: Equatable, Sendable {
    enum Variant: Equatable, Sendable {
        /// The app's normal state.
        case night
        /// Shown only once a watch has completed.
        case dawn
    }

    var variant: Variant
    var isHighContrast: Bool
    var background: Color
    var raisedBackground: Color
    var primaryText: Color
    var secondaryText: Color
    var action: Color
    var onAction: Color
    var focusRing: Color
    var divider: Color
    var completed: Color
    /// Interruption is information, not failure: never red.
    var interrupted: Color

    static func make(_ variant: Variant, highContrast: Bool) -> Theme {
        switch variant {
        case .night:
            Theme(
                variant: .night,
                isHighContrast: highContrast,
                background: Palette.night,
                raisedBackground: Palette.deepSea,
                primaryText: Palette.moon,
                secondaryText: highContrast ? Palette.moon : Palette.mist,
                action: Palette.lantern,
                onAction: Palette.ink,
                focusRing: highContrast ? Palette.moon : Palette.lantern,
                divider: highContrast ? Palette.mist : Palette.horizon,
                completed: Palette.dawn,
                interrupted: highContrast ? Palette.moon : Palette.mist
            )
        case .dawn:
            Theme(
                variant: .dawn,
                isHighContrast: highContrast,
                background: Palette.moon,
                raisedBackground: Color(hex: 0xF2F6F7),
                primaryText: Palette.ink,
                secondaryText: highContrast ? Palette.ink : Palette.horizon,
                action: Palette.ink,
                onAction: Palette.moon,
                focusRing: Palette.ink,
                divider: highContrast ? Palette.horizon : Palette.mist,
                completed: Palette.ink,
                interrupted: Palette.horizon
            )
        }
    }

    static let night = Theme.make(.night, highContrast: false)
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.night
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

private struct ThemedModifier: ViewModifier {
    let variant: Theme.Variant
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.environment(\.theme, Theme.make(variant, highContrast: contrast == .increased))
    }
}

extension View {
    /// Applies a palette at a feature boundary, reading the system contrast setting once.
    func themed(_ variant: Theme.Variant) -> some View {
        modifier(ThemedModifier(variant: variant))
    }
}
