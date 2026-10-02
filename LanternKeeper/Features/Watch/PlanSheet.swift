import SwiftUI

/// Watch length and the optional morning notification.
struct PlanSheet: View {
    let flow: WatchFlowModel

    @State private var plan: WatchPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    init(flow: WatchFlowModel) {
        self.flow = flow
        _plan = State(initialValue: flow.harbour.plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    DurationPicker(plan: $plan, format: flow.format, now: flow.now)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Toggle(isOn: notificationBinding) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Morning notification")
                                    .font(TypeScale.body)
                                    .foregroundStyle(theme.primaryText)
                                Text("A quiet notification when your watch is complete.")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                        .tint(theme.action)
                        .frame(minHeight: Metrics.minimumTarget)
                        .accessibilityIdentifier("plan.notificationToggle")

                        if let notice = flow.notificationNotice {
                            NoticeText(message: notice)
                                .accessibilityIdentifier("plan.notificationNotice")
                        }
                    }
                }
                .padding(Spacing.screenMargin)
            }
            .background(theme.background)
            .navigationTitle("Watch length")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        flow.choosePlan(plan)
                        dismiss()
                    }
                    .accessibilityIdentifier("plan.done")
                }
            }
            .toolbarBackground(theme.background, for: .navigationBar)
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
