import Foundation
import Observation
import SwiftUI

/// Owns the ritual: harbour → face-down prompt → active watch → ended. Every path into
/// a watch goes through `begin()`, and every lifecycle rule is enforced by `WatchStore`.
@MainActor
@Observable
final class WatchFlowModel {
    enum Screen: Equatable {
        case harbour
        case prompt
        case active(ActiveWatch)
        case ended(EndedWatch)
    }

    struct ActiveWatch: Equatable {
        let id: UUID
        let startedAt: Date
        let targetEndAt: Date

        init(_ session: WatchSession) {
            id = session.id
            startedAt = session.startedAt
            targetEndAt = session.targetEndAt
        }

        func progress(at now: Date) -> Double {
            let total = targetEndAt.timeIntervalSince(startedAt)
            guard total > 0 else { return 1 }
            return min(1, max(0, now.timeIntervalSince(startedAt) / total))
        }
    }

    struct EndedWatch: Equatable {
        let id: UUID
        let completed: Bool
        let startedAt: Date
        let endedAt: Date
        let duration: TimeInterval

        init(_ session: WatchSession) {
            id = session.id
            completed = session.status == .completed
            startedAt = session.startedAt
            endedAt = session.endedAt ?? session.targetEndAt
            duration = session.measuredDuration ?? 0
        }
    }

    enum Copy {
        static let saveFailed = String(localized: "The watch could not be saved. Try again before putting your phone down.")
        static let updateFailed = String(localized: "That change could not be saved. Try again.")
        static let notificationsDenied = String(localized: "Morning notifications are off. Your watch will still continue.")
        static let motionUnavailable = String(localized: "Turn detection isn’t available. Start the watch when you’re ready.")
    }

    private(set) var screen: Screen = .harbour
    private(set) var saveError: String?
    private(set) var orientationNotice: String?
    private(set) var notificationNotice: String?
    private(set) var morningNotificationEnabled: Bool
    /// Set when a watch has just begun and its ignition (and haptic) has not played yet.
    private(set) var ignitionPending = false
    var isPlanSheetPresented = false
    var isLogbookPresented = false
    var isSettingsPresented = false
    private(set) var onboardingCompleted: Bool
    private(set) var hapticsEnabled: Bool

    let harbour: HarbourModel

    @ObservationIgnored private let watchStore: WatchStore
    @ObservationIgnored private let clock: any Clock
    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let notifications: any NotificationService
    @ObservationIgnored private let haptics: any HapticsService
    @ObservationIgnored private let persistenceAvailable: Bool
    @ObservationIgnored private let announce: @MainActor (String) -> Void
    @ObservationIgnored private(set) var notificationWork: Task<Void, Never>?

    init(
        store: WatchStore,
        clock: any Clock,
        preferences: any PreferencesStore,
        notifications: any NotificationService,
        haptics: any HapticsService,
        format: WatchFormat,
        persistenceAvailable: Bool = true,
        announce: @escaping @MainActor (String) -> Void = WatchFlowModel.postAnnouncement
    ) {
        self.watchStore = store
        self.clock = clock
        self.preferences = preferences
        self.notifications = notifications
        self.haptics = haptics
        self.persistenceAvailable = persistenceAvailable
        self.announce = announce
        harbour = HarbourModel(clock: clock, preferences: preferences, format: format)
        let stored = preferences.load()
        morningNotificationEnabled = stored.morningNotificationEnabled
        onboardingCompleted = stored.onboardingCompleted
        hapticsEnabled = stored.hapticsEnabled
    }

    var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    func setHaptics(_ enabled: Bool) {
        hapticsEnabled = enabled
        var stored = preferences.load()
        stored.hapticsEnabled = enabled
        preferences.save(stored)
        if enabled { haptics.play(.selection) }
    }

    /// Irreversible. Ended watches only; an active watch keeps running.
    func deleteAllHistory() -> Bool {
        do {
            try watchStore.deleteAllHistory()
            return true
        } catch {
            saveError = Copy.updateFailed
            return false
        }
    }

    func makeLogbook() -> LogbookModel {
        LogbookModel(store: watchStore, clock: clock, format: format)
    }

    var store: WatchStore { watchStore }
    var preferencesStore: any PreferencesStore { preferences }
    var hapticsService: any HapticsService { haptics }
    var notificationService: any NotificationService { notifications }

    func completeOnboarding() {
        onboardingCompleted = true
        var stored = preferences.load()
        stored.onboardingCompleted = true
        preferences.save(stored)
    }

    /// Optional morning reflection and note for the watch just shown.
    func saveReflection(_ reflection: MorningReflection?, note: String?, for ended: EndedWatch) {
        do {
            guard let session = try watchStore.session(id: ended.id) else { return }
            try watchStore.updateReflection(reflection, note: note, for: session)
            haptics.play(.selection)
        } catch {
            saveError = Copy.updateFailed
        }
    }

    var now: Date { clock.now }
    var format: WatchFormat { harbour.format }

    // MARK: Lifecycle

    /// Reconciles stored state with the clock. Idempotent; call on launch, on becoming
    /// active, and when a running watch reaches its end time.
    func refresh() {
        do {
            switch try watchStore.reconcile() {
            case .noActiveWatch:
                if case .active = screen { screen = .harbour }
            case .stillActive(let session):
                screen = .active(ActiveWatch(session))
            case .completed(let session):
                notifications.cancelWatchComplete()
                screen = .ended(EndedWatch(session))
                haptics.play(.completion)
                announce(String(localized: "Morning. Watch completed."))
            }
        } catch {
            saveError = Copy.updateFailed
        }
    }

    func requestBegin() {
        saveError = nil
        orientationNotice = nil
        refresh()
        if screen == .harbour { screen = .prompt }
    }

    func cancelPrompt() {
        guard screen == .prompt else { return }
        saveError = nil
        screen = .harbour
    }

    /// The single way a watch starts, shared by the face-down gesture and the button.
    func begin() {
        guard screen == .prompt else { return }
        guard persistenceAvailable else {
            saveError = Copy.saveFailed
            return
        }
        do {
            let session = try watchStore.begin(plan: harbour.plan)
            harbour.choose(harbour.plan)
            saveError = nil
            screen = .active(ActiveWatch(session))
            ignitionPending = true
            announce(String(localized: "Watch started. Lighthouse lit. Watch ends at \(format.time(session.targetEndAt))."))
            if morningNotificationEnabled {
                let target = session.targetEndAt
                notificationWork?.cancel()
                notificationWork = Task { await notifications.scheduleWatchComplete(at: target) }
            }
        } catch WatchError.activeWatchExists {
            refresh()
        } catch WatchError.endNotInFuture {
            saveError = String(localized: "That end time has passed. Choose another before you begin.")
        } catch {
            saveError = Copy.saveFailed
        }
    }

    /// The single confirming haptic, after the beam's first sweep (or at once with Reduce Motion).
    func completeIgnition() {
        guard ignitionPending else { return }
        ignitionPending = false
        haptics.play(.ignition)
    }

    func orientationUnavailable() {
        orientationNotice = Copy.motionUnavailable
    }

    func endEarly() {
        do {
            let session = try watchStore.interrupt()
            notificationWork?.cancel()
            notifications.cancelWatchComplete()
            screen = .ended(EndedWatch(session))
            announce(String(localized: "Watch ended early. Watch time \(format.spokenDuration(session.measuredDuration ?? 0))."))
        } catch WatchError.notActive {
            refresh()
        } catch {
            saveError = Copy.updateFailed
        }
    }

    func dismissEnded() {
        guard case .ended = screen else { return }
        screen = .harbour
    }

    // MARK: Preferences

    func choosePlan(_ plan: WatchPlan) {
        harbour.choose(plan)
        haptics.play(.selection)
    }

    /// Asks for permission only here, after the user turns the notification on.
    func setMorningNotification(_ enabled: Bool) async {
        notificationNotice = nil
        guard enabled else {
            store(morningNotification: false)
            notifications.cancelWatchComplete()
            return
        }

        var status = await notifications.authorization()
        if status == .notDetermined {
            status = await notifications.requestAuthorization()
        }
        guard status == .allowed else {
            store(morningNotification: false)
            notificationNotice = Copy.notificationsDenied
            return
        }
        store(morningNotification: true)
        if case .active(let watch) = screen {
            await notifications.scheduleWatchComplete(at: watch.targetEndAt)
        }
    }

    private func store(morningNotification enabled: Bool) {
        morningNotificationEnabled = enabled
        var stored = preferences.load()
        stored.morningNotificationEnabled = enabled
        preferences.save(stored)
    }

    static func postAnnouncement(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
