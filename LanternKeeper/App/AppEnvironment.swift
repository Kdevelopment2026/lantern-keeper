import Foundation
import SwiftData

/// Builds and owns the app's services. Tests and UI-test launches substitute fakes.
@MainActor
final class AppEnvironment {
    let clock: any Clock
    let preferences: any PreferencesStore
    let format: WatchFormat
    let container: ModelContainer
    let store: WatchStore
    let notifications: any NotificationService
    let orientation: any OrientationService
    let haptics: any HapticsService
    /// False when the on-disk store could not open. Watches then refuse to start rather
    /// than pretend to be saved.
    let persistenceAvailable: Bool

    init(
        clock: any Clock,
        preferences: any PreferencesStore,
        format: WatchFormat,
        container: ModelContainer,
        notifications: any NotificationService,
        orientation: any OrientationService,
        haptics: any HapticsService,
        persistenceAvailable: Bool = true
    ) {
        self.clock = clock
        self.preferences = preferences
        self.format = format
        self.container = container
        self.notifications = notifications
        self.orientation = orientation
        self.haptics = haptics
        self.persistenceAvailable = persistenceAvailable
        store = WatchStore(context: container.mainContext, clock: clock, calendar: format.calendar)
    }

    static func makeForLaunch() -> AppEnvironment {
        let arguments = LaunchArguments(ProcessInfo.processInfo.arguments)
        if arguments.isUITest {
            return makeUITest(arguments)
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Unit tests run inside the app; keep them away from the real store.
            return AppEnvironment(
                clock: SystemClock(),
                preferences: InMemoryPreferencesStore(),
                format: .current,
                container: try! Persistence.makeContainer(inMemory: true),
                notifications: FakeNotificationService(),
                orientation: FakeOrientationService(),
                haptics: RecordingHapticsService()
            )
        }
        return makeLive()
    }

    static func makeLive() -> AppEnvironment {
        let preferences = UserDefaultsPreferencesStore()
        let container: ModelContainer
        var persistenceAvailable = true
        do {
            container = try Persistence.makeContainer()
        } catch {
            container = try! Persistence.makeContainer(inMemory: true)
            persistenceAvailable = false
        }
        return AppEnvironment(
            clock: SystemClock(),
            preferences: preferences,
            format: .current,
            container: container,
            notifications: UserNotificationService(),
            orientation: MotionOrientationService(),
            haptics: CoreHapticsService(isEnabled: { preferences.load().hapticsEnabled }),
            persistenceAvailable: persistenceAvailable
        )
    }

    private static func makeUITest(_ arguments: LaunchArguments) -> AppEnvironment {
        let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("uitest.store")
        let defaults = UserDefaults(suiteName: "uitest") ?? .standard
        if arguments.reset {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            defaults.removePersistentDomain(forName: "uitest")
        }
        let clock: any Clock = arguments.now.map(FixedClock.init) ?? SystemClock()
        return AppEnvironment(
            clock: clock,
            preferences: UserDefaultsPreferencesStore(defaults: defaults),
            format: .current,
            container: try! Persistence.makeContainer(url: storeURL),
            notifications: FakeNotificationService(
                status: .notDetermined,
                responseToRequest: arguments.notificationsDenied ? .denied : .allowed
            ),
            orientation: FakeOrientationService(faceDownAfter: arguments.faceDownAfter),
            haptics: RecordingHapticsService()
        )
    }
}

/// Launch arguments understood by UI tests. Ignored in normal launches.
struct LaunchArguments {
    let isUITest: Bool
    let reset: Bool
    let now: Date?
    let notificationsDenied: Bool
    let faceDownAfter: TimeInterval?

    init(_ arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        isUITest = arguments.contains("-uitest")
        reset = arguments.contains("-uitest-reset")
        now = value(after: "-uitest-now").flatMap { ISO8601DateFormatter().date(from: $0) }
        notificationsDenied = arguments.contains("-uitest-notifications-denied")
        faceDownAfter = value(after: "-uitest-facedown-after").flatMap(TimeInterval.init)
    }
}
