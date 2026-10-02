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

    init(clock: any Clock, preferences: any PreferencesStore, format: WatchFormat, container: ModelContainer) {
        self.clock = clock
        self.preferences = preferences
        self.format = format
        self.container = container
        store = WatchStore(context: container.mainContext, clock: clock, calendar: format.calendar)
    }

    /// Unit tests run inside the app; keep them away from the real store.
    static func makeForLaunch() -> AppEnvironment {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return AppEnvironment(
                clock: SystemClock(),
                preferences: InMemoryPreferencesStore(),
                format: .current,
                container: try! Persistence.makeContainer(inMemory: true)
            )
        }
        return makeLive()
    }

    static func makeLive() -> AppEnvironment {
        let container: ModelContainer
        do {
            container = try Persistence.makeContainer()
        } catch {
            // Fall back so the app still opens; saves will surface errors to the user.
            container = try! Persistence.makeContainer(inMemory: true)
        }
        return AppEnvironment(
            clock: SystemClock(),
            preferences: UserDefaultsPreferencesStore(),
            format: .current,
            container: container
        )
    }
}
