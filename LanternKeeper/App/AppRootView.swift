import SwiftUI

struct AppRootView: View {
    let environment: AppEnvironment
    @State private var flow: WatchFlowModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(environment: AppEnvironment) {
        self.environment = environment
        _flow = State(initialValue: WatchFlowModel(
            store: environment.store,
            clock: environment.clock,
            preferences: environment.preferences,
            notifications: environment.notifications,
            haptics: environment.haptics,
            format: environment.format,
            persistenceAvailable: environment.persistenceAvailable
        ))
    }

    var body: some View {
        ZStack {
            if flow.onboardingCompleted {
                screen
                    .transition(.opacity)
            } else {
                OnboardingView(onFinish: flow.completeOnboarding)
                    .themed(.night)
                    .transition(.opacity)
            }
        }
        .animation(Motion.stateChange(reduceMotion: reduceMotion), value: flow.screen)
        .animation(Motion.stateChange(reduceMotion: reduceMotion), value: flow.onboardingCompleted)
        .sheet(isPresented: $flow.isPlanSheetPresented) {
            PlanSheet(flow: flow)
                .themed(.night)
        }
        .sheet(isPresented: $flow.isLogbookPresented) {
            LogbookView(model: flow.makeLogbook())
                .themed(.night)
        }
        .sheet(isPresented: $flow.isSettingsPresented) {
            SettingsView(flow: flow)
                .themed(.night)
        }
        .preferredColorScheme(.dark)
        .task { flow.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { flow.refresh() }
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch flow.screen {
        case .harbour:
            HarbourView(
                model: flow.harbour,
                onBegin: flow.requestBegin,
                onChangePlan: { flow.isPlanSheetPresented = true },
                onOpenLogbook: { flow.isLogbookPresented = true },
                onOpenSettings: { flow.isSettingsPresented = true }
            )
            .themed(.night)
        case .prompt:
            FaceDownPromptView(flow: flow, orientation: environment.orientation)
                .themed(.night)
        case .active(let watch):
            ActiveWatchView(flow: flow, watch: watch)
                .themed(.night)
        case .ended(let ended):
            MorningLogView(flow: flow, ended: ended)
                .themed(ended.completed ? .dawn : .night)
        }
    }
}
