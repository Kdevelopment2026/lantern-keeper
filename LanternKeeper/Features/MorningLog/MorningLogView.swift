import SwiftUI

/// The result of a watch, stated plainly, then an optional reflection and note.
struct MorningLogView: View {
    let flow: WatchFlowModel
    let ended: WatchFlowModel.EndedWatch

    @State private var reflection: MorningReflection?
    @State private var note = ""
    static let noteLimit = 500
    @FocusState private var noteFocused: Bool
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let state: LighthouseSceneState = ended.completed ? .dawn : .interrupted
        ScreenScaffold {
            AnimatedLighthouseScene(state: state, reduceMotion: reduceMotion, highContrast: theme.isHighContrast)
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

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("How do you feel this morning?")
                    .font(TypeScale.body)
                    .foregroundStyle(theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                ReflectionSelector(selection: $reflection)
                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .font(TypeScale.body)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1...4)
                    .padding(Spacing.s)
                    .surface()
                    .focused($noteFocused)
                    .submitLabel(.done)
                    .onSubmit { noteFocused = false }
                    .onChange(of: note) { _, newValue in
                        if newValue.count > Self.noteLimit { note = String(newValue.prefix(Self.noteLimit)) }
                    }
                    .accessibilityIdentifier("ended.note")
            }

            if let error = flow.saveError {
                NoticeText(message: error)
            }

            PrimaryActionButton("Done") {
                noteFocused = false
                if reflection != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    flow.saveReflection(reflection, note: note, for: ended)
                }
                flow.dismissEnded()
            }
            .accessibilityIdentifier("ended.done")
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
