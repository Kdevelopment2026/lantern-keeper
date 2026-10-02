import Foundation
import OSLog
import SwiftData

enum ReconcileOutcome: Equatable {
    case noActiveWatch
    case stillActive(WatchSession)
    case completed(WatchSession)
}

/// Owns every watch lifecycle rule. Views and feature models call into it; they never
/// change a `WatchSession` directly.
@MainActor
final class WatchStore {
    typealias SaveHandler = @MainActor (ModelContext) throws -> Void

    private let context: ModelContext
    private let clock: any Clock
    private let calendar: Calendar
    private let save: SaveHandler
    private static let logger = Logger(subsystem: "com.kayode.lanternkeeper", category: "lifecycle")

    init(
        context: ModelContext,
        clock: any Clock,
        calendar: Calendar = .autoupdatingCurrent,
        save: @escaping SaveHandler = { try $0.save() }
    ) {
        self.context = context
        self.clock = clock
        self.calendar = calendar
        self.save = save
    }

    var now: Date { clock.now }

    // MARK: Queries

    func activeWatch() throws -> WatchSession? {
        try fetchActive().first
    }

    /// Ended watches, newest first.
    func logbook() throws -> [WatchSession] {
        let active = WatchStatus.active.rawValue
        let descriptor = FetchDescriptor<WatchSession>(
            predicate: #Predicate { $0.statusRawValue != active },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: Lifecycle

    /// Starts a watch. Throws, and leaves nothing behind, if it cannot be saved.
    @discardableResult
    func begin(plan: WatchPlan) throws -> WatchSession {
        try reconcile()
        guard try activeWatch() == nil else { throw WatchError.activeWatchExists }

        let start = clock.now
        let target = try plan.targetEnd(from: start, calendar: calendar)
        let session = WatchSession(startedAt: start, targetEndAt: target)
        context.insert(session)
        try commit()
        Self.logger.info("watch begun")
        return session
    }

    /// Brings stored state in line with the clock. Safe to call any number of times.
    @discardableResult
    func reconcile() throws -> ReconcileOutcome {
        let actives = try fetchActive()
        guard let newest = actives.first else { return .noActiveWatch }
        let now = clock.now

        // Corruption guard: more than one active record should never exist.
        for stale in actives.dropFirst() {
            if now >= stale.targetEndAt {
                try stale.markCompleted()
            } else {
                try stale.markInterrupted(at: newest.startedAt)
            }
            Self.logger.notice("duplicate active watch resolved")
        }

        let outcome: ReconcileOutcome
        if now >= newest.targetEndAt {
            try newest.markCompleted()
            outcome = .completed(newest)
            Self.logger.info("active watch completed")
        } else {
            outcome = .stillActive(newest)
        }

        if context.hasChanges { try commit() }
        Self.logger.debug("active watch reconciled")
        return outcome
    }

    /// Ends the active watch early. If the target has already passed, the watch completes
    /// instead and this throws `notActive`.
    @discardableResult
    func interrupt() throws -> WatchSession {
        try reconcile()
        guard let active = try activeWatch() else { throw WatchError.notActive }
        try active.markInterrupted(at: clock.now)
        try commit()
        Self.logger.info("active watch ended early")
        return active
    }

    // MARK: History

    func updateReflection(_ reflection: MorningReflection?, note: String?, for session: WatchSession) throws {
        try session.setReflection(reflection, note: note)
        try commit()
    }

    func delete(_ session: WatchSession) throws {
        guard session.status != .active else { throw WatchError.stillActive }
        context.delete(session)
        try commit()
    }

    /// Removes every ended watch. An active watch is left running.
    func deleteAllHistory() throws {
        for session in try logbook() {
            context.delete(session)
        }
        try commit()
        Self.logger.info("history deleted")
    }

    // MARK: Private

    private func fetchActive() throws -> [WatchSession] {
        let active = WatchStatus.active.rawValue
        let descriptor = FetchDescriptor<WatchSession>(
            predicate: #Predicate { $0.statusRawValue == active },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func commit() throws {
        do {
            try save(context)
        } catch {
            context.rollback()
            Self.logger.error("watch store save failed")
            throw WatchError.persistenceFailed
        }
    }
}
