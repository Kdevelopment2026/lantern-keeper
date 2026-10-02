import Foundation

/// Locale- and time-zone-aware formatting for times and durations.
struct WatchFormat: Sendable {
    var calendar: Calendar
    var locale: Locale

    static let current = WatchFormat(calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent)

    /// Clock time, e.g. "7:00 AM" or "07:00".
    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(
            date: .omitted, time: .shortened,
            locale: locale, calendar: calendar, timeZone: calendar.timeZone
        ))
    }

    /// Measured watch time, rounded down to the minute: "7 hr 42 min".
    func duration(_ interval: TimeInterval) -> String {
        format(minutes: Int64(max(0, interval) / 60), width: .abbreviated)
    }

    /// Spoken form for VoiceOver: "7 hours, 42 minutes".
    func spokenDuration(_ interval: TimeInterval) -> String {
        format(minutes: Int64(max(0, interval) / 60), width: .wide)
    }

    /// Time left, rounded up so the display never reads zero while a watch is running.
    func remaining(_ interval: TimeInterval) -> String {
        format(minutes: Int64((max(0, interval) / 60).rounded(.up)), width: .abbreviated)
    }

    func spokenRemaining(_ interval: TimeInterval) -> String {
        format(minutes: Int64((max(0, interval) / 60).rounded(.up)), width: .wide)
    }

    private func format(minutes: Int64, width: Duration.UnitsFormatStyle.UnitWidth) -> String {
        Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: width, zeroValueUnits: .hide)
                .locale(locale)
        )
    }
}
