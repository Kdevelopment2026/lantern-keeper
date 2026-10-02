import SwiftUI

/// The single dominant action on a screen.
struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    var accessibilityHint: LocalizedStringKey?
    let action: () -> Void

    init(_ title: LocalizedStringKey, accessibilityHint: LocalizedStringKey? = nil, action: @escaping () -> Void) {
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Metrics.primaryButtonHeight)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityHint(accessibilityHint ?? "")
    }
}

/// A visible but quieter action, such as ending a watch.
struct SecondaryActionButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget)
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}

/// A text-only link-style action with a full 44 pt target.
struct QuietActionButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .underline(true, pattern: .solid)
                .multilineTextAlignment(.leading)
                .frame(minWidth: Metrics.minimumTarget, minHeight: Metrics.minimumTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.button)
            .foregroundStyle(theme.onAction)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(theme.action))
            .overlay {
                if theme.isHighContrast {
                    Capsule().strokeBorder(theme.focusRing, lineWidth: Metrics.focusRingWidthHighContrast)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
            .contentShape(Capsule())
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.body)
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .overlay {
                Capsule().strokeBorder(
                    theme.isHighContrast ? theme.primaryText : theme.divider,
                    lineWidth: theme.isHighContrast ? Metrics.focusRingWidthHighContrast : Metrics.hairline
                )
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

private struct QuietButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.label)
            .foregroundStyle(theme.secondaryText)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
