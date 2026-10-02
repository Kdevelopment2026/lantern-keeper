import Foundation

/// How the user chose to set a watch: a length of time, or a clock time to end at.
enum WatchPlan: Equatable, Codable, Sendable {
    case duration(TimeInterval)
    case endTime(hour: Int, minute: Int)

    static let `default` = WatchPlan.duration(8 * 3600)

    /// The longest watch the app will schedule.
    static let maximumDuration: TimeInterval = 16 * 3600

    /// Resolves the plan to an absolute end date.
    ///
    /// Durations add elapsed seconds, so a daylight-saving change never stretches or shrinks
    /// the watch. End times resolve to the next matching wall-clock time in `calendar`.
    func targetEnd(from start: Date, calendar: Calendar) throws -> Date {
        let target: Date
        switch self {
        case .duration(let interval):
            guard interval > 0, interval <= Self.maximumDuration else { throw WatchError.endNotInFuture }
            target = start.addingTimeInterval(interval)
        case .endTime(let hour, let minute):
            guard (0..<24).contains(hour), (0..<60).contains(minute),
                  let next = calendar.nextDate(
                    after: start,
                    matching: DateComponents(hour: hour, minute: minute, second: 0),
                    matchingPolicy: .nextTime,
                    repeatedTimePolicy: .first,
                    direction: .forward
                  )
            else { throw WatchError.endNotInFuture }
            target = next
        }
        guard target > start else { throw WatchError.endNotInFuture }
        return target
    }
}
