import SwiftUI

/// The light is on. Shows end time, time left and the lighthouse; nothing to browse.
struct ActiveWatchView: View {
    let flow: WatchFlowModel
    let watch: WatchFlowModel.ActiveWatch

    @State private var isConfirmingEnd = false
    @State private var isQuiet = false
    @State private var ignitionStart: Date?
    @State private var controlsVisible = true
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lighthouseAmbienceEnabled) private var ambienceEnabled

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { _ in
            let now = flow.now
            let state = LighthouseSceneState.watching(progress: watch.progress(at: now))
            let endTime = flow.format.time(watch.targetEndAt)
            let remaining = watch.targetEndAt.timeIntervalSince(now)

            ScreenScaffold {
                AnimatedLighthouseScene(
                    state: state,
                    reduceMotion: reduceMotion,
                    highContrast: theme.isHighContrast,
                    ignitionStart: ignitionStart
                )
            } top: {
                EmptyView()
            } bottom: {
                WatchStatusLabel(
                    state: state,
                    detail: String(localized: "You can lock your phone. The watch continues."),
                    endTime: endTime
                )
                .accessibilityIdentifier("active.status")

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Watch ends at")
                        .font(TypeScale.label)
                        .foregroundStyle(theme.secondaryText)
                    Text(endTime)
                        .font(TypeScale.timeDisplay)
                        .foregroundStyle(theme.primaryText)
                    Text("\(flow.format.remaining(remaining)) left")
                        .font(TypeScale.timeSmall)
                        .foregroundStyle(theme.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Watch ends at \(endTime). \(flow.format.spokenRemaining(remaining)) left."))
                .accessibilityIdentifier("active.timing")

                if let error = flow.saveError {
                    NoticeText(message: error)
                }

                Group {
                if isQuiet {
                    QuietActionButton("Show watch controls") { isQuiet = false }
                        .accessibilityIdentifier("active.showControls")
                } else {
                    PrimaryActionButton("Return to watch") { isQuiet = true }
                        .accessibilityIdentifier("active.returnToWatch")
                    SecondaryActionButton("End watch") { isConfirmingEnd = true }
                        .accessibilityIdentifier("active.endWatch")
                }
                }
                .opacity(controlsVisible ? 1 : 0)
            }
        }
        .onAppear(perform: startIgnitionIfNeeded)
        .task(id: ignitionStart) {
            guard ignitionStart != nil else { return }
            try? await Task.sleep(for: .seconds(IgnitionTimeline.hapticTime))
            guard !Task.isCancelled else { return }
            flow.completeIgnition()
        }
        .confirmationDialog("End this watch now?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End watch") { flow.endEarly() }
                .accessibilityIdentifier("active.confirmEnd")
            Button("Keep watching", role: .cancel) {}
        } message: {
            Text("It will be logged as ended early, with the watch time so far.")
        }
        .task(id: watch.targetEndAt) {
            let wait = watch.targetEndAt.timeIntervalSince(flow.now)
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            flow.refresh()
        }
    }

    /// Plays the ignition only for a watch that has just begun, never on reopen.
    private func startIgnitionIfNeeded() {
        guard flow.ignitionPending else { return }
        guard !reduceMotion, ambienceEnabled else {
            flow.completeIgnition()
            return
        }
        ignitionStart = Date()
        controlsVisible = false
        withAnimation(.easeOut(duration: Motion.ignitionControlsSettle).delay(IgnitionTimeline.hapticTime)) {
            controlsVisible = true
        }
    }
}
