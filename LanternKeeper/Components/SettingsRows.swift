import SwiftUI

/// A tappable settings row with a title, current value and chevron.
struct SettingsLinkRow: View {
    let title: LocalizedStringKey
    var value: String?
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) {
                    Text(title).foregroundStyle(theme.primaryText)
                    Spacer()
                    if let value { Text(value).foregroundStyle(theme.secondaryText) }
                    chevron
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack { Text(title).foregroundStyle(theme.primaryText); Spacer(); chevron }
                    if let value { Text(value).foregroundStyle(theme.secondaryText) }
                }
            }
            .font(TypeScale.body)
            .frame(minHeight: Metrics.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(TypeScale.caption)
            .foregroundStyle(theme.secondaryText)
            .accessibilityHidden(true)
    }
}

/// A toggle row with an optional explanation below the title.
struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @Binding var isOn: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(TypeScale.body)
                    .foregroundStyle(theme.primaryText)
                if let detail {
                    Text(detail)
                        .font(TypeScale.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .tint(theme.action)
        .frame(minHeight: Metrics.minimumTarget)
    }
}
