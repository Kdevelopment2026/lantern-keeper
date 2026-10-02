import SwiftUI

/// The result of a watch, stated plainly. The full morning log arrives in a later build.
struct WatchEndedView: View {
    let flow: WatchFlowModel
    let ended: WatchFlowModel.EndedWatch

    @Environment(\.theme) private var theme

    var body: some View {
        let state: LighthouseSceneState = ended.completed ? .dawn : .interrupted
        ScreenScaffold {
            LighthouseScene(state: state, highContrast: theme.isHighContrast)
        } top: {
            EmptyView()
        } bottom: {
            WatchStatusLabel(
                state: state,
                detail: ended.completed
                    ? String(localized: "Your watch is complete.")
                    : String(localized: "No judgement. Begin again tonight.")
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(ended.completed ? "Watch kept for" : "Watch time")
                    .font(TypeScale.label)
                    .foregroundStyle(theme.secondaryText)
                Text(flow.format.duration(ended.duration))
                    .font(TypeScale.time)
                    .foregroundStyle(theme.primaryText)
                Text("\(flow.format.time(ended.startedAt)) to \(flow.format.time(ended.endedAt))")
                    .font(TypeScale.timeSmall)
                    .foregroundStyle(theme.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(
                "\(ended.completed ? "Watch kept for" : "Watch time") \(flow.format.spokenDuration(ended.duration)), from \(flow.format.time(ended.startedAt)) to \(flow.format.time(ended.endedAt))."
            ))
            .accessibilityIdentifier("ended.duration")

            PrimaryActionButton("Done", action: flow.dismissEnded)
                .accessibilityIdentifier("ended.done")
        }
    }
}
