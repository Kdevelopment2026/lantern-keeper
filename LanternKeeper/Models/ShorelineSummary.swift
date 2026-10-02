import Foundation

/// The last seven nights as a quiet row of marks, plus the time kept across them.
/// Nights are attributed to the calendar day a watch began.
struct ShorelineSummary: Equatable {
    struct Night: Equatable, Identifiable {
        let day: Date
        /// `nil` means no watch that night. Completed wins if a day has both.
        let status: WatchStatus?
        var id: Date { day }
    }

    let nights: [Night]
    let totalWatchTime: TimeInterval
    let completedCount: Int

    static let nightCount = 7

    static func lastSevenNights(from sessions: [WatchSession], now: Date, calendar: Calendar) -> ShorelineSummary {
        let today = calendar.startOfDay(for: now)
        let days: [Date] = (0..<nightCount).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        guard let firstDay = days.first else {
            return ShorelineSummary(nights: [], totalWatchTime: 0, completedCount: 0)
        }

        var statusByDay: [Date: WatchStatus] = [:]
        var total: TimeInterval = 0
        var completed = 0
        for session in sessions where session.status != .active && session.startedAt >= firstDay {
            let day = calendar.startOfDay(for: session.startedAt)
            total += session.measuredDuration ?? 0
            if session.status == .completed {
                completed += 1
                statusByDay[day] = .completed
            } else if statusByDay[day] == nil {
                statusByDay[day] = .interrupted
            }
        }

        return ShorelineSummary(
            nights: days.map { Night(day: $0, status: statusByDay[$0]) },
            totalWatchTime: total,
            completedCount: completed
        )
    }
}
