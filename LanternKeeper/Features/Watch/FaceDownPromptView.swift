import SwiftUI

/// "Turn your phone face down." The gesture is optional; the button is always visible and
/// both call the same `WatchFlowModel.begin()`.
struct FaceDownPromptView: View {
    let flow: WatchFlowModel
    let orientation: any OrientationService

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let end = flow.harbour.proposedEnd(at: flow.now)
        ScreenScaffold {
            AnimatedLighthouseScene(state: .idle, reduceMotion: reduceMotion, highContrast: theme.isHighContrast)
        } top: {
            QuietActionButton("Not now", action: flow.cancelPrompt)
                .accessibilityIdentifier("prompt.notNow")
        } bottom: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Turn your phone face down.")
                    .font(TypeScale.reflectiveHeading)
                    .foregroundStyle(theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if let end {
                    Text("The light comes on and keeps watch until \(flow.format.time(end)).")
                        .font(TypeScale.body)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if let notice = flow.orientationNotice {
                NoticeText(message: notice)
                    .accessibilityIdentifier("prompt.orientationNotice")
            }
            if let error = flow.saveError {
                NoticeText(message: error)
                    .accessibilityIdentifier("prompt.error")
            }

            PrimaryActionButton("Start without turning over", action: flow.begin)
                .accessibilityIdentifier("prompt.startWithoutTurning")
        }
        .task {
            for await event in orientation.faceDownEvents() {
                switch event {
                case .faceDown: flow.begin()
                case .unavailable: flow.orientationUnavailable()
                }
            }
        }
    }
}
