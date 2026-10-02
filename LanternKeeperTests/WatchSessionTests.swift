import XCTest
@testable import LanternKeeper

final class WatchSessionTests: XCTestCase {
    private let start = date("2026-06-10T22:00:00Z")

    func testProgressIsClamped() {
        let watch = WatchSession(startedAt: start, targetEndAt: start.addingTimeInterval(8 * hour))

        XCTAssertEqual(watch.progress(at: start.addingTimeInterval(-hour)), 0)
        XCTAssertEqual(watch.progress(at: start.addingTimeInterval(2 * hour)), 0.25)
        XCTAssertEqual(watch.progress(at: start.addingTimeInterval(20 * hour)), 1)
    }

    func testRemainingDerivesFromTarget() {
        let watch = WatchSession(startedAt: start, targetEndAt: start.addingTimeInterval(8 * hour))

        XCTAssertEqual(watch.remaining(at: start.addingTimeInterval(3 * hour)), 5 * hour)
        XCTAssertEqual(watch.remaining(at: start.addingTimeInterval(9 * hour)), 0)
    }

    func testUnknownStatusIsNeverActive() {
        let watch = WatchSession(startedAt: start, targetEndAt: start.addingTimeInterval(hour))
        watch.statusRawValue = "archived"

        XCTAssertEqual(watch.status, .interrupted)
    }

    func testCompletedRecordCannotTransitionAgain() throws {
        let watch = WatchSession(startedAt: start, targetEndAt: start.addingTimeInterval(hour))
        try watch.markCompleted()

        XCTAssertThrowsError(try watch.markInterrupted(at: start))
        XCTAssertThrowsError(try watch.markCompleted())
        XCTAssertEqual(watch.endedAt, watch.targetEndAt)
    }

    func testInterruptionIsClampedToWatchWindow() throws {
        let watch = WatchSession(startedAt: start, targetEndAt: start.addingTimeInterval(hour))
        try watch.markInterrupted(at: start.addingTimeInterval(-60))

        XCTAssertEqual(watch.measuredDuration, 0)
    }
}

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testRoundTripsThroughUserDefaults() throws {
        let suite = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.load(), UserPreferences())
        var preferences = UserPreferences()
        preferences.lastPlan = .endTime(hour: 6, minute: 45)
        preferences.hapticsEnabled = false
        store.save(preferences)

        XCTAssertEqual(UserDefaultsPreferencesStore(defaults: defaults).load(), preferences)
    }

    func testDefaultIsEightHours() {
        XCTAssertEqual(UserPreferences().lastPlan, .duration(8 * hour))
    }
}
