import XCTest
@testable import LanternKeeper

@MainActor
final class ShorelineSummaryTests: XCTestCase {
    private func session(start: String, hours: Double, status: WatchStatus) throws -> WatchSession {
        let s = WatchSession(startedAt: date(start), targetEndAt: date(start).addingTimeInterval(hours * hour))
        if status == .completed { try s.markCompleted() }
        if status == .interrupted { try s.markInterrupted(at: s.startedAt.addingTimeInterval(hours * hour / 2)) }
        return s
    }

    func testSevenNightsOldestFirstWithStatusAndTotals() throws {
        let now = date("2026-06-16T08:00:00Z") // Tuesday morning, BST
        let sessions = [
            try session(start: "2026-06-15T22:30:00Z", hours: 8, status: .completed),   // Mon night
            try session(start: "2026-06-14T22:30:00Z", hours: 8, status: .interrupted), // Sun night, 4 h kept
            try session(start: "2026-06-14T21:00:00Z", hours: 1, status: .completed),   // Sun, completed wins
            try session(start: "2026-06-01T22:30:00Z", hours: 8, status: .completed),   // too old
        ]

        let summary = ShorelineSummary.lastSevenNights(from: sessions, now: now, calendar: .london)

        XCTAssertEqual(summary.nights.count, 7)
        XCTAssertEqual(summary.nights.last?.day, Calendar.london.startOfDay(for: now))
        XCTAssertEqual(summary.nights.map(\.status), [nil, nil, nil, nil, .completed, .completed, nil])
        XCTAssertEqual(summary.totalWatchTime, 8 * hour + 4 * hour + 1 * hour)
        XCTAssertEqual(summary.completedCount, 2)
    }

    func testActiveWatchIsIgnored() {
        let now = date("2026-06-16T08:00:00Z")
        let active = WatchSession(startedAt: date("2026-06-15T22:30:00Z"), targetEndAt: date("2026-06-16T06:30:00Z"))
        let summary = ShorelineSummary.lastSevenNights(from: [active], now: now, calendar: .london)
        XCTAssertEqual(summary.totalWatchTime, 0)
        XCTAssertTrue(summary.nights.allSatisfy { $0.status == nil })
    }
}

final class PreferencesMigrationTests: XCTestCase {
    func testMissingKeysKeepDefaults() throws {
        let legacy = Data(#"{"lastPlan":{"duration":{"_0":21600}},"hapticsEnabled":false}"#.utf8)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: legacy)
        XCTAssertEqual(decoded.lastPlan, .duration(6 * hour))
        XCTAssertFalse(decoded.hapticsEnabled)
        XCTAssertFalse(decoded.onboardingCompleted)
        XCTAssertFalse(decoded.morningNotificationEnabled)
    }
}

@MainActor
final class LogbookModelTests: XCTestCase {
    func testLoadsNewestFirstAndDeletesOnlyConfirmedEntry() throws {
        let clock = FixedClock(date("2026-06-10T22:30:00Z"))
        let (store, _) = try makeStore(clock: clock)
        let older = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        let newer = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        try store.reconcile()
        let model = LogbookModel(store: store, clock: clock, format: WatchFormat(calendar: .london, locale: Locale(identifier: "en_GB")))

        model.reload()
        XCTAssertEqual(model.entries.map(\.id), [newer.id, older.id])
        XCTAssertEqual(model.shoreline.completedCount, 2)

        model.pendingDeletion = model.entries[1]
        model.confirmDeletion()

        XCTAssertEqual(model.entries.map(\.id), [newer.id])
        XCTAssertNil(model.pendingDeletion)
        XCTAssertNil(model.errorMessage)
    }
}
