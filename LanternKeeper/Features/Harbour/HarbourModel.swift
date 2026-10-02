import Foundation
import Observation

/// Home screen state: what watch would begin if the user started now.
@MainActor
@Observable
final class HarbourModel {
    @ObservationIgnored private let clock: any Clock
    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored let format: WatchFormat

    private(set) var plan: WatchPlan

    init(clock: any Clock, preferences: any PreferencesStore, format: WatchFormat) {
        self.clock = clock
        self.preferences = preferences
        self.format = format
        plan = preferences.load().lastPlan
    }

    var now: Date { clock.now }

    func proposedEnd(at now: Date) -> Date? {
        try? plan.targetEnd(from: now, calendar: format.calendar)
    }

    /// Remembers a plan only if it would produce a valid watch right now.
    func choose(_ plan: WatchPlan) {
        guard (try? plan.targetEnd(from: clock.now, calendar: format.calendar)) != nil else { return }
        self.plan = plan
        var stored = preferences.load()
        stored.lastPlan = plan
        preferences.save(stored)
    }

    func planSummary(at now: Date) -> String {
        guard let end = proposedEnd(at: now) else { return "" }
        return String(localized: "\(format.duration(end.timeIntervalSince(now))) from now")
    }
}
