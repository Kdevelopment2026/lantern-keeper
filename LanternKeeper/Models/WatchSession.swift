import Foundation
import SwiftData

/// One watch. Stores absolute dates only; durations are always derived.
@Model
final class WatchSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var targetEndAt: Date
    var endedAt: Date?
    var statusRawValue: String
    var reflectionRawValue: String?
    var note: String?

    init(id: UUID = UUID(), startedAt: Date, targetEndAt: Date) {
        self.id = id
        self.startedAt = startedAt
        self.targetEndAt = targetEndAt
        self.endedAt = nil
        self.statusRawValue = WatchStatus.active.rawValue
        self.reflectionRawValue = nil
        self.note = nil
    }

    /// Unknown raw values from a future schema read as interrupted, never as active.
    var status: WatchStatus {
        WatchStatus(rawValue: statusRawValue) ?? .interrupted
    }

    var reflection: MorningReflection? {
        reflectionRawValue.flatMap(MorningReflection.init(rawValue:))
    }

    /// Watch time kept. `nil` while the watch is active.
    var measuredDuration: TimeInterval? {
        guard status != .active, let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    func remaining(at now: Date) -> TimeInterval {
        max(0, targetEndAt.timeIntervalSince(now))
    }

    /// Fraction of the planned watch that has passed, clamped to `0...1`.
    func progress(at now: Date) -> Double {
        let total = targetEndAt.timeIntervalSince(startedAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / total))
    }

    // MARK: Lifecycle transitions

    /// `active → completed`. The end is stamped at the planned target, not when the app
    /// noticed, so opening the app late never adds time that was not planned.
    func markCompleted() throws {
        guard status == .active else { throw WatchError.notActive }
        endedAt = targetEndAt
        statusRawValue = WatchStatus.completed.rawValue
    }

    /// `active → interrupted`.
    func markInterrupted(at date: Date) throws {
        guard status == .active else { throw WatchError.notActive }
        endedAt = min(max(date, startedAt), targetEndAt)
        statusRawValue = WatchStatus.interrupted.rawValue
    }

    /// Reflection and note are the only fields that may change after a watch ends.
    func setReflection(_ reflection: MorningReflection?, note: String?) throws {
        guard status != .active else { throw WatchError.stillActive }
        reflectionRawValue = reflection?.rawValue
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
