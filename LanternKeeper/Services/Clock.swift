import Foundation

protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

/// A settable clock for tests and UI-test launches.
final class FixedClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var now: Date {
        lock.withLock { current }
    }

    func set(_ date: Date) {
        lock.withLock { current = date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }
}
