import Foundation
import SwiftData

/// Sample history for App Store screenshots and UI tests. Only reachable through the
/// `-uitest-seed-demo` launch argument; never used in a normal launch.
enum DemoData {
    static func seed(into context: ModelContext, now: Date, calendar: Calendar) throws {
        func night(daysAgo: Int, startHour: Int, startMinute: Int, hours: Double, completed: Bool,
                   reflection: MorningReflection? = nil, note: String? = nil) throws {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
            let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day)!
            let session = WatchSession(startedAt: start, targetEndAt: start.addingTimeInterval(8 * 3600))
            if completed {
                try session.markCompleted()
            } else {
                try session.markInterrupted(at: start.addingTimeInterval(hours * 3600))
            }
            try session.setReflection(reflection, note: note)
            context.insert(session)
        }
        try night(daysAgo: 1, startHour: 23, startMinute: 12, hours: 8, completed: true, reflection: .clear, note: "Quiet night.")
        try night(daysAgo: 2, startHour: 23, startMinute: 48, hours: 8, completed: true, reflection: .steady)
        try night(daysAgo: 3, startHour: 0, startMinute: 20, hours: 2.25, completed: false)
        try night(daysAgo: 4, startHour: 22, startMinute: 55, hours: 8, completed: true, reflection: .tired)
        try night(daysAgo: 6, startHour: 23, startMinute: 30, hours: 8, completed: true)
        try context.save()
    }

    /// A watch that began three hours ago, for the active screen.
    static func seedActiveWatch(into context: ModelContext, now: Date) throws {
        let session = WatchSession(startedAt: now.addingTimeInterval(-3 * 3600), targetEndAt: now.addingTimeInterval(5 * 3600))
        context.insert(session)
        try context.save()
    }

    /// A watch whose end time has just passed, so reconciling shows the morning log.
    static func seedCompletedWatch(into context: ModelContext, now: Date) throws {
        let session = WatchSession(startedAt: now.addingTimeInterval(-8 * 3600 - 20 * 60), targetEndAt: now.addingTimeInterval(-20 * 60))
        context.insert(session)
        try context.save()
    }
}
