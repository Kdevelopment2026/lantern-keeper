import SwiftUI

struct LogbookView: View {
    let model: LogbookModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ShorelineView(summary: model.shoreline, format: model.format)
                        .padding(.vertical, Spacing.xs)
                        .listRowBackground(theme.raisedBackground)
                }

                if let message = model.errorMessage {
                    Section {
                        NoticeText(message: message)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section {
                    if model.entries.isEmpty {
                        Text("No watches yet. Your first one will appear here in the morning.")
                            .font(TypeScale.body)
                            .foregroundStyle(theme.secondaryText)
                            .listRowBackground(theme.raisedBackground)
                            .accessibilityIdentifier("logbook.empty")
                    }
                    ForEach(model.entries) { entry in
                        LogbookRow(entry: entry, format: model.format)
                            .listRowBackground(theme.raisedBackground)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete") { model.pendingDeletion = entry }
                                    .tint(theme.horizon)
                            }
                            .accessibilityAction(named: Text("Delete")) { model.pendingDeletion = entry }
                    }
                } header: {
                    Text("Watches")
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("logbook.done")
                }
            }
            .toolbarBackground(theme.background, for: .navigationBar)
            .confirmationDialog(
                "Delete this watch?",
                isPresented: Binding(get: { model.pendingDeletion != nil }, set: { if !$0 { model.pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete watch", role: .destructive) { model.confirmDeletion() }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("It is removed from this phone, with its reflection and note. This can’t be undone.")
            }
        }
        .tint(theme.primaryText)
        .presentationBackground(theme.background)
        .task { model.reload() }
    }
}

private extension Theme {
    var horizon: Color { Palette.horizon }
}

struct LogbookRow: View {
    let entry: LogbookModel.Entry
    let format: WatchFormat

    @Environment(\.theme) private var theme

    private var statusText: String {
        entry.status == .completed ? String(localized: "Completed") : String(localized: "Ended early")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: entry.status == .completed ? "sailboat.fill" : "circle.dotted")
                    .foregroundStyle(entry.status == .completed ? theme.action : theme.interrupted)
                    .accessibilityHidden(true)
                Text(format.day(entry.startedAt))
                    .font(TypeScale.body)
                    .foregroundStyle(theme.primaryText)
            }
            Text("\(format.duration(entry.duration)) · \(statusText)")
                .font(TypeScale.timeSmall)
                .foregroundStyle(theme.secondaryText)
            Text("\(format.time(entry.startedAt)) to \(format.time(entry.endedAt))")
                .font(TypeScale.caption)
                .foregroundStyle(theme.secondaryText)
            if entry.reflection != nil || entry.note != nil {
                Text([entry.reflection?.spokenTitle, entry.note].compactMap { $0 }.joined(separator: " · "))
                    .font(TypeScale.caption)
                    .foregroundStyle(theme.primaryText)
                    .padding(.top, Spacing.xxs)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(format.day(entry.startedAt)), \(statusText), \(format.spokenDuration(entry.duration)), \(format.time(entry.startedAt)) to \(format.time(entry.endedAt)). \([entry.reflection?.spokenTitle, entry.note].compactMap { $0 }.joined(separator: ". "))"
        ))
        .accessibilityIdentifier("logbook.entry")
    }
}
