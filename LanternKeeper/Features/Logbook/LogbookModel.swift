import Foundation
import Observation

/// History, newest first, with a quiet seven-night shoreline.
@MainActor
@Observable
final class LogbookModel {
    struct Entry: Identifiable, Equatable {
        let id: UUID
        let status: WatchStatus
        let startedAt: Date
        let endedAt: Date
        let duration: TimeInterval
        let reflection: MorningReflection?
        let note: String?

        init(_ session: WatchSession) {
            id = session.id
            status = session.status
            startedAt = session.startedAt
            endedAt = session.endedAt ?? session.targetEndAt
            duration = session.measuredDuration ?? 0
            reflection = session.reflection
            note = session.note
        }
    }

    private(set) var entries: [Entry] = []
    private(set) var shoreline = ShorelineSummary(nights: [], totalWatchTime: 0, completedCount: 0)
    private(set) var errorMessage: String?
    var pendingDeletion: Entry?

    @ObservationIgnored private let store: WatchStore
    @ObservationIgnored private let clock: any Clock
    @ObservationIgnored let format: WatchFormat

    init(store: WatchStore, clock: any Clock, format: WatchFormat) {
        self.store = store
        self.clock = clock
        self.format = format
    }

    func reload() {
        do {
            let sessions = try store.logbook()
            entries = sessions.map(Entry.init)
            shoreline = ShorelineSummary.lastSevenNights(from: sessions, now: clock.now, calendar: format.calendar)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "The logbook could not be read. Try again.")
        }
    }

    func confirmDeletion() {
        guard let entry = pendingDeletion else { return }
        pendingDeletion = nil
        do {
            if let session = try store.session(id: entry.id) {
                try store.delete(session)
            }
        } catch {
            errorMessage = String(localized: "That entry could not be deleted. Try again.")
        }
        reload()
    }
}
