import SwiftUI

struct SettingsView: View {
    let flow: WatchFlowModel

    @State private var isPlanSheetPresented = false
    @State private var isConfirmingDeleteAll = false
    @State private var historyDeleted = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SettingsLinkRow(title: "Default watch length", value: flow.harbour.planSummary(at: flow.now)) {
                        isPlanSheetPresented = true
                    }
                    .listRowBackground(theme.raisedBackground)
                    .accessibilityIdentifier("settings.watchLength")

                    SettingsToggleRow(
                        title: "Morning notification",
                        detail: "One quiet notification when your watch is complete.",
                        isOn: notificationBinding
                    )
                    .listRowBackground(theme.raisedBackground)
                    .accessibilityIdentifier("settings.notifications")

                    if let notice = flow.notificationNotice {
                        NoticeText(message: notice)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }

                    SettingsToggleRow(
                        title: "Haptics",
                        detail: "A single tap when the light comes on and when a watch completes.",
                        isOn: Binding(get: { flow.hapticsEnabled }, set: { flow.setHaptics($0) })
                    )
                    .listRowBackground(theme.raisedBackground)
                    .accessibilityIdentifier("settings.haptics")
                } header: {
                    Text("Watch").foregroundStyle(theme.secondaryText)
                }

                Section {
                    Text("Everything stays on this phone. Lantern Keeper has no account, no analytics and no network access. Motion is read only while the face-down screen is open and is never stored. The app measures time away from your phone; it does not know whether you slept.")
                        .font(TypeScale.caption)
                        .foregroundStyle(theme.secondaryText)
                        .listRowBackground(theme.raisedBackground)
                } header: {
                    Text("Privacy").foregroundStyle(theme.secondaryText)
                }

                Section {
                    Button("Delete all history") { isConfirmingDeleteAll = true }
                        .font(TypeScale.body)
                        .foregroundStyle(theme.primaryText)
                        .frame(minHeight: Metrics.minimumTarget)
                        .listRowBackground(theme.raisedBackground)
                        .accessibilityIdentifier("settings.deleteAll")
                    if historyDeleted {
                        NoticeText(message: String(localized: "History deleted."))
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .accessibilityIdentifier("settings.historyDeleted")
                    }
                } header: {
                    Text("History").foregroundStyle(theme.secondaryText)
                } footer: {
                    Text("Removes every completed and ended watch, with reflections and notes. An active watch continues.")
                        .foregroundStyle(theme.secondaryText)
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(flow.versionDescription)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .font(TypeScale.body)
                    .foregroundStyle(theme.primaryText)
                    .listRowBackground(theme.raisedBackground)
                    .accessibilityElement(children: .combine)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
            .toolbarBackground(theme.background, for: .navigationBar)
            .confirmationDialog("Delete all history?", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete all history", role: .destructive) {
                    historyDeleted = flow.deleteAllHistory()
                }
                .accessibilityIdentifier("settings.confirmDeleteAll")
                Button("Keep history", role: .cancel) {}
            } message: {
                Text("Every completed and ended watch on this phone will be removed, including reflections and notes. This can’t be undone.")
            }
            .sheet(isPresented: $isPlanSheetPresented) {
                PlanSheet(flow: flow, showsNotificationToggle: false).themed(.night)
            }
        }
        .tint(theme.primaryText)
        .presentationBackground(theme.background)
    }

    private var notificationBinding: Binding<Bool> {
        Binding {
            flow.morningNotificationEnabled
        } set: { enabled in
            Task { await flow.setMorningNotification(enabled) }
        }
    }
}
