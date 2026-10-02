import SwiftUI

/// Calm, informational message. Never styled as an alarm.
struct NoticeText: View {
    let message: String

    @Environment(\.theme) private var theme

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
        }
        .font(TypeScale.label)
        .foregroundStyle(theme.primaryText)
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface()
    }
}
