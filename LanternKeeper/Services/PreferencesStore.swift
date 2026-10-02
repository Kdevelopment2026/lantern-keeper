import Foundation

@MainActor
protocol PreferencesStore: AnyObject {
    func load() -> UserPreferences
    func save(_ preferences: UserPreferences)
}

@MainActor
final class UserDefaultsPreferencesStore: PreferencesStore {
    private let defaults: UserDefaults
    private let key = "preferences.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else { return UserPreferences() }
        return preferences
    }

    func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class InMemoryPreferencesStore: PreferencesStore {
    private var stored: UserPreferences

    init(_ preferences: UserPreferences = UserPreferences()) {
        stored = preferences
    }

    func load() -> UserPreferences { stored }
    func save(_ preferences: UserPreferences) { stored = preferences }
}
