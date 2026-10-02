import SwiftData
import XCTest
@testable import LanternKeeper

@MainActor
final class WatchStoreTests: XCTestCase {
    private var clock: FixedClock!

    override func setUp() async throws {
        clock = FixedClock(date("2026-06-10T22:30:00Z"))
    }

    // MARK: Starting

    func testStartsValidWatch() throws {
        let (store, _) = try makeStore(clock: clock)
        let watch = try store.begin(plan: .duration(8 * hour))

        XCTAssertEqual(watch.status, .active)
        XCTAssertEqual(watch.startedAt, clock.now)
        XCTAssertEqual(watch.targetEndAt, clock.now.addingTimeInterval(8 * hour))
        XCTAssertNil(watch.endedAt)
        XCTAssertNil(watch.measuredDuration)
        XCTAssertEqual(try store.activeWatch(), watch)
    }

    func testRejectsEndTimeNotInFuture() throws {
        let (store, _) = try makeStore(clock: clock)

        XCTAssertThrowsError(try store.begin(plan: .duration(0))) {
            XCTAssertEqual($0 as? WatchError, .endNotInFuture)
        }
        XCTAssertThrowsError(try store.begin(plan: .duration(-hour))) {
            XCTAssertEqual($0 as? WatchError, .endNotInFuture)
        }
        XCTAssertThrowsError(try store.begin(plan: .endTime(hour: 25, minute: 0))) {
            XCTAssertEqual($0 as? WatchError, .endNotInFuture)
        }
        XCTAssertNil(try store.activeWatch())
    }

    func testPreventsTwoActiveWatches() throws {
        let (store, container) = try makeStore(clock: clock)
        try store.begin(plan: .duration(8 * hour))
        clock.advance(by: 60)

        XCTAssertThrowsError(try store.begin(plan: .duration(hour))) {
            XCTAssertEqual($0 as? WatchError, .activeWatchExists)
        }
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<WatchSession>()), 1)
    }

    func testStartingAfterPreviousTargetReconcilesFirst() throws {
        let (store, _) = try makeStore(clock: clock)
        let first = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)

        let second = try store.begin(plan: .duration(hour))

        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(second.status, .active)
    }

    func testFailedSaveNeverReportsAStartedWatch() throws {
        let (store, container) = try makeStore(clock: clock, save: { _ in throw SaveFailure() })

        XCTAssertThrowsError(try store.begin(plan: .duration(8 * hour))) {
            XCTAssertEqual($0 as? WatchError, .persistenceFailed)
        }
        XCTAssertNil(try store.activeWatch())
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<WatchSession>()), 0)
    }

    // MARK: Restoring and completing

    func testRestoresActiveWatchInNewStore() throws {
        let (store, container) = try makeStore(clock: clock)
        let original = try store.begin(plan: .duration(8 * hour))
        clock.advance(by: 3 * hour)

        let (relaunched, _) = try makeStore(clock: clock, container: container)
        let outcome = try relaunched.reconcile()

        guard case .stillActive(let restored) = outcome else {
            return XCTFail("Expected still active, got \(outcome)")
        }
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.remaining(at: clock.now), 5 * hour)
    }

    func testCompletesExactlyOnceAfterTarget() throws {
        let (store, _) = try makeStore(clock: clock)
        let watch = try store.begin(plan: .duration(8 * hour))
        clock.advance(by: 8 * hour)

        guard case .completed(let completed) = try store.reconcile() else {
            return XCTFail("Expected completion at the target time")
        }
        XCTAssertEqual(completed.id, watch.id)
        XCTAssertEqual(try store.reconcile(), .noActiveWatch)

        clock.advance(by: 5 * hour)
        XCTAssertEqual(try store.reconcile(), .noActiveWatch)
        XCTAssertEqual(watch.status, .completed)
        XCTAssertEqual(try store.logbook().count, 1)
    }

    func testLateReopenStampsCompletionAtTarget() throws {
        let (store, _) = try makeStore(clock: clock)
        let watch = try store.begin(plan: .duration(8 * hour))
        clock.advance(by: 11 * hour)

        try store.reconcile()

        XCTAssertEqual(watch.endedAt, watch.targetEndAt)
        XCTAssertEqual(watch.measuredDuration, 8 * hour)
    }

    func testReconcileBeforeTargetLeavesWatchActive() throws {
        let (store, _) = try makeStore(clock: clock)
        try store.begin(plan: .duration(8 * hour))
        clock.advance(by: 8 * hour - 1)

        guard case .stillActive = try store.reconcile() else {
            return XCTFail("Watch should still be active one second before its target")
        }
    }

    func testDuplicateActiveRecordsAreResolvedToOne() throws {
        let (store, container) = try makeStore(clock: clock)
        let context = ModelContext(container)
        let older = WatchSession(startedAt: clock.now, targetEndAt: clock.now.addingTimeInterval(8 * hour))
        let newer = WatchSession(
            startedAt: clock.now.addingTimeInterval(hour),
            targetEndAt: clock.now.addingTimeInterval(9 * hour)
        )
        context.insert(older)
        context.insert(newer)
        try context.save()
        clock.advance(by: 2 * hour)

        guard case .stillActive(let survivor) = try store.reconcile() else {
            return XCTFail("Expected the newest record to stay active")
        }
        XCTAssertEqual(survivor.id, newer.id)
        XCTAssertEqual(try store.logbook().map(\.status), [.interrupted])
    }

    // MARK: Ending early

    func testEarlyEndIsRecordedAsInterrupted() throws {
        let (store, _) = try makeStore(clock: clock)
        try store.begin(plan: .duration(8 * hour))
        clock.advance(by: 2 * hour + 15 * 60)

        let ended = try store.interrupt()

        XCTAssertEqual(ended.status, .interrupted)
        XCTAssertEqual(ended.measuredDuration, 2 * hour + 15 * 60)
        XCTAssertNil(try store.activeWatch())
    }

    func testInterruptHappensOnlyOnce() throws {
        let (store, _) = try makeStore(clock: clock)
        try store.begin(plan: .duration(8 * hour))
        clock.advance(by: hour)
        let ended = try store.interrupt()
        clock.advance(by: hour)

        XCTAssertThrowsError(try store.interrupt()) {
            XCTAssertEqual($0 as? WatchError, .notActive)
        }
        XCTAssertEqual(ended.measuredDuration, hour)
    }

    func testEndingAfterTargetCompletesInsteadOfInterrupting() throws {
        let (store, _) = try makeStore(clock: clock)
        let watch = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)

        XCTAssertThrowsError(try store.interrupt()) {
            XCTAssertEqual($0 as? WatchError, .notActive)
        }
        XCTAssertEqual(watch.status, .completed)
    }

    // MARK: Calendar edge cases

    func testWatchCrossesMidnight() throws {
        clock.set(date("2026-06-10T22:30:00Z")) // 23:30 BST
        let (store, _) = try makeStore(clock: clock)

        let watch = try store.begin(plan: .endTime(hour: 6, minute: 30))

        XCTAssertEqual(watch.targetEndAt, date("2026-06-11T05:30:00Z"))
        XCTAssertEqual(watch.targetEndAt.timeIntervalSince(watch.startedAt), 7 * hour)
        clock.set(watch.targetEndAt)
        try store.reconcile()
        XCTAssertEqual(watch.measuredDuration, 7 * hour)
    }

    func testEndTimeEarlierThanNowMeansTomorrow() throws {
        clock.set(date("2026-06-10T07:00:00Z")) // 08:00 BST
        let (store, _) = try makeStore(clock: clock)

        let watch = try store.begin(plan: .endTime(hour: 7, minute: 0))

        XCTAssertEqual(watch.targetEndAt, date("2026-06-11T06:00:00Z"))
    }

    func testSpringForwardKeepsDurationsAbsolute() throws {
        // Clocks go forward at 01:00 GMT on 29 March 2026 in London.
        clock.set(date("2026-03-28T23:00:00Z")) // 23:00 GMT
        let (store, _) = try makeStore(clock: clock)

        let watch = try store.begin(plan: .duration(8 * hour))
        XCTAssertEqual(watch.targetEndAt, date("2026-03-29T07:00:00Z")) // 08:00 BST

        clock.set(watch.targetEndAt)
        try store.reconcile()
        XCTAssertEqual(watch.measuredDuration, 8 * hour)
    }

    func testSpringForwardEndTimeIsSevenRealHours() throws {
        clock.set(date("2026-03-28T23:00:00Z"))
        let (store, _) = try makeStore(clock: clock)

        let watch = try store.begin(plan: .endTime(hour: 7, minute: 0))

        XCTAssertEqual(watch.targetEndAt, date("2026-03-29T06:00:00Z")) // 07:00 BST
        XCTAssertEqual(watch.targetEndAt.timeIntervalSince(watch.startedAt), 7 * hour)
    }

    func testFallBackEndTimeIsNineRealHours() throws {
        // Clocks go back at 02:00 BST on 25 October 2026 in London.
        clock.set(date("2026-10-24T22:00:00Z")) // 23:00 BST
        let (store, _) = try makeStore(clock: clock)

        let watch = try store.begin(plan: .endTime(hour: 7, minute: 0))

        XCTAssertEqual(watch.targetEndAt, date("2026-10-25T07:00:00Z")) // 07:00 GMT
        XCTAssertEqual(watch.targetEndAt.timeIntervalSince(watch.startedAt), 9 * hour)
    }

    func testFallBackDurationStaysEightRealHours() throws {
        clock.set(date("2026-10-24T22:00:00Z"))
        let (store, _) = try makeStore(clock: clock)

        let watch = try store.begin(plan: .duration(8 * hour))

        XCTAssertEqual(watch.targetEndAt, date("2026-10-25T06:00:00Z"))
    }

    // MARK: History

    func testLogbookIsNewestFirstAndExcludesActive() throws {
        let (store, _) = try makeStore(clock: clock)
        let first = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        let second = try store.begin(plan: .duration(hour))
        clock.advance(by: 30 * 60)
        try store.interrupt()
        try store.begin(plan: .duration(hour))

        XCTAssertEqual(try store.logbook().map(\.id), [second.id, first.id])
    }

    func testDeletionRemovesOnlyTheChosenEntry() throws {
        let (store, _) = try makeStore(clock: clock)
        let keep = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        let remove = try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        try store.reconcile()

        try store.delete(remove)

        XCTAssertEqual(try store.logbook().map(\.id), [keep.id])
    }

    func testDeletingActiveWatchIsRejected() throws {
        let (store, _) = try makeStore(clock: clock)
        let active = try store.begin(plan: .duration(hour))

        XCTAssertThrowsError(try store.delete(active)) {
            XCTAssertEqual($0 as? WatchError, .stillActive)
        }
    }

    func testDeleteAllHistoryKeepsActiveWatch() throws {
        let (store, _) = try makeStore(clock: clock)
        try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        try store.begin(plan: .duration(hour))
        clock.advance(by: 2 * hour)
        let running = try store.begin(plan: .duration(8 * hour))

        try store.deleteAllHistory()

        XCTAssertTrue(try store.logbook().isEmpty)
        XCTAssertEqual(try store.activeWatch()?.id, running.id)
    }

    func testReflectionDoesNotChangeMeasuredDuration() throws {
        let (store, _) = try makeStore(clock: clock)
        let watch = try store.begin(plan: .duration(7 * hour + 42 * 60))
        clock.advance(by: 9 * hour)
        try store.reconcile()
        let before = (watch.startedAt, watch.targetEndAt, watch.endedAt, watch.measuredDuration)

        try store.updateReflection(.steady, note: "  Quiet night.  ", for: watch)

        XCTAssertEqual(watch.reflection, .steady)
        XCTAssertEqual(watch.note, "Quiet night.")
        XCTAssertEqual(watch.startedAt, before.0)
        XCTAssertEqual(watch.targetEndAt, before.1)
        XCTAssertEqual(watch.endedAt, before.2)
        XCTAssertEqual(watch.measuredDuration, before.3)

        try store.updateReflection(nil, note: "   ", for: watch)
        XCTAssertNil(watch.reflection)
        XCTAssertNil(watch.note)
    }

    func testReflectionOnActiveWatchIsRejected() throws {
        let (store, _) = try makeStore(clock: clock)
        let watch = try store.begin(plan: .duration(hour))

        XCTAssertThrowsError(try store.updateReflection(.clear, note: nil, for: watch)) {
            XCTAssertEqual($0 as? WatchError, .stillActive)
        }
    }
}
