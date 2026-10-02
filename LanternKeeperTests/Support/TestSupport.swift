import Foundation
import SwiftData
@testable import LanternKeeper

func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: iso) else { fatalError("Bad ISO date \(iso)") }
    return date
}

let hour: TimeInterval = 3600

extension Calendar {
    static func fixed(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    static let london = Calendar.fixed("Europe/London")
}

struct SaveFailure: Error {}

@MainActor
func makeStore(
    clock: FixedClock,
    container: ModelContainer? = nil,
    calendar: Calendar = .london,
    save: WatchStore.SaveHandler? = nil
) throws -> (WatchStore, ModelContainer) {
    let container = try container ?? Persistence.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let store = save.map { WatchStore(context: context, clock: clock, calendar: calendar, save: $0) }
        ?? WatchStore(context: context, clock: clock, calendar: calendar)
    return (store, container)
}
