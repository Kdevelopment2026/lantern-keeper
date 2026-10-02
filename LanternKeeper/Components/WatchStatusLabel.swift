import SwiftUI

/// Plain-language state of the lighthouse. Always present, so the metaphor is never the
/// only way to understand whether a watch is running.
enum WatchStatusText {
    static func title(for state: LighthouseSceneState) -> String {
        switch state {
        case .idle: String(localized: "The light is off")
        case .igniting, .watching: String(localized: "The light is on")
        case .dawn: String(localized: "Morning")
        case .interrupted: String(localized: "Watch ended early")
        }
    }

    /// One concise VoiceOver label for the whole scene.
    static func accessibilityLabel(for state: LighthouseSceneState, endTime: String?) -> String {
        switch state {
        case .idle:
            return String(localized: "Lighthouse dark. No watch is active.")
        case .igniting, .watching:
            guard let endTime else { return String(localized: "Lighthouse lit. Watch is active.") }
            return String(localized: "Lighthouse lit. Watch ends at \(endTime).")
        case .dawn:
            return String(localized: "Dawn. Watch completed.")
        case .interrupted:
            return String(localized: "Lighthouse dark. Watch ended early.")
        }
    }
}

struct WatchStatusLabel: View {
    let state: LighthouseSceneState
    var detail: String?
    var endTime: String?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(WatchStatusText.title(for: state))
                .font(TypeScale.title)
                .foregroundStyle(theme.primaryText)
            if let detail {
                Text(detail)
                    .font(TypeScale.body)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WatchStatusText.accessibilityLabel(for: state, endTime: endTime))
        .accessibilityAddTraits(.isHeader)
    }
}
