import SwiftUI

/// Home. Answers: is a watch active, when would one end, and what to do next.
struct HarbourView: View {
    let model: HarbourModel
    var onBegin: () -> Void = {}
    var onChangePlan: () -> Void = {}

    @Environment(\.theme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let now = model.now
            ScreenScaffold {
                LighthouseScene(state: .idle, highContrast: theme.isHighContrast)
            } top: {
                Text(model.format.time(now))
                    .font(TypeScale.timeSmall)
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityLabel(Text("Current time, \(model.format.time(now))"))
            } bottom: {
                WatchStatusLabel(state: .idle, detail: String(localized: "No watch is active."))

                if let end = model.proposedEnd(at: now) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Keep watch until")
                            .font(TypeScale.label)
                            .foregroundStyle(theme.secondaryText)
                        Text(model.format.time(end))
                            .font(TypeScale.timeDisplay)
                            .foregroundStyle(theme.primaryText)
                        Text(model.planSummary(at: now))
                            .font(TypeScale.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Keep watch until \(model.format.time(end)), \(model.planSummary(at: now))"))
                }

                QuietActionButton("Change watch length", action: onChangePlan)
                    .accessibilityIdentifier("harbour.changePlan")

                PrimaryActionButton(
                    "Begin watch",
                    accessibilityHint: "Next, you’ll be asked to put your phone face down.",
                    action: onBegin
                )
                .accessibilityIdentifier("harbour.beginWatch")
            }
        }
    }
}
