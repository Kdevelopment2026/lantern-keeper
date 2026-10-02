import SwiftData
import XCTest
@testable import LanternKeeper

@MainActor
final class WatchFlowModelTests: XCTestCase {
    private var clock: FixedClock!
    private var notifications: FakeNotificationService!
    private var haptics: RecordingHapticsService!
    private var preferences: InMemoryPreferencesStore!
    private var announcements: [String] = []

    override func setUp() async throws {
        clock = FixedClock(date("2026-06-10T22:42:00Z"))
        notifications = FakeNotificationService()
        haptics = RecordingHapticsService()
        preferences = InMemoryPreferencesStore()
        announcements = []
    }

    private func makeFlow(
        container: ModelContainer? = nil,
        save: WatchStore.SaveHandler? = nil,
        persistenceAvailable: Bool = true
    ) throws -> (WatchFlowModel, WatchStore) {
        let (store, _) = try makeStore(clock: clock, container: container, save: save)
        let flow = WatchFlowModel(
            store: store,
            clock: clock,
            preferences: preferences,
            notifications: notifications,
            haptics: haptics,
            format: WatchFormat(calendar: .london, locale: Locale(identifier: "en_GB")),
            persistenceAvailable: persistenceAvailable,
            announce: { [unowned self] in announcements.append($0) }
        )
        return (flow, store)
    }

    // MARK: Starting

    func testButtonAndGestureShareOneStart() throws {
        let (flow, store) = try makeFlow()
        flow.requestBegin()
        XCTAssertEqual(flow.screen, .prompt)

        flow.begin() // button
        flow.begin() // a late face-down event must not start a second watch

        guard case .active(let watch) = flow.screen else { return XCTFail("Expected active watch") }
        XCTAssertEqual(watch.targetEndAt, clock.now.addingTimeInterval(8 * hour))
        XCTAssertEqual(try store.activeWatch()?.id, watch.id)
        XCTAssertEqual(announcements.count, 1)

        // One haptic, played when the ignition completes.
        XCTAssertTrue(flow.ignitionPending)
        XCTAssertTrue(haptics.played.isEmpty)
        flow.completeIgnition()
        flow.completeIgnition()
        XCTAssertEqual(haptics.played, [.ignition])
        XCTAssertFalse(flow.ignitionPending)
    }

    func testRestoredWatchDoesNotReplayIgnition() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let (first, _) = try makeFlow(container: container)
        first.requestBegin()
        first.begin()

        let (relaunched, _) = try makeFlow(container: container)
        relaunched.refresh()

        XCTAssertFalse(relaunched.ignitionPending)
    }

    func testBeginOutsidePromptDoesNothing() throws {
        let (flow, store) = try makeFlow()
        flow.begin()

        XCTAssertEqual(flow.screen, .harbour)
        XCTAssertNil(try store.activeWatch())
    }

    func testFailedSaveStaysOnPromptWithMessage() throws {
        let (flow, store) = try makeFlow(save: { _ in throw SaveFailure() })
        flow.requestBegin()
        flow.begin()

        XCTAssertEqual(flow.screen, .prompt)
        XCTAssertEqual(flow.saveError, WatchFlowModel.Copy.saveFailed)
        XCTAssertNil(try store.activeWatch())
        XCTAssertTrue(haptics.played.isEmpty)
    }

    func testUnavailableStoreRefusesToStart() throws {
        let (flow, store) = try makeFlow(persistenceAvailable: false)
        flow.requestBegin()
        flow.begin()

        XCTAssertEqual(flow.screen, .prompt)
        XCTAssertEqual(flow.saveError, WatchFlowModel.Copy.saveFailed)
        XCTAssertNil(try store.activeWatch())
    }

    func testChosenPlanIsRemembered() throws {
        let (flow, _) = try makeFlow()
        flow.choosePlan(.duration(6 * hour))

        let (relaunched, _) = try makeFlow()
        XCTAssertEqual(relaunched.harbour.plan, .duration(6 * hour))
    }

    func testMotionUnavailableShowsNotice() throws {
        let (flow, _) = try makeFlow()
        flow.requestBegin()
        flow.orientationUnavailable()

        XCTAssertEqual(flow.orientationNotice, WatchFlowModel.Copy.motionUnavailable)
        flow.begin()
        guard case .active = flow.screen else { return XCTFail("Button must still start the watch") }
    }

    // MARK: Restoring, completing, ending

    func testRefreshRestoresActiveWatch() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let (first, _) = try makeFlow(container: container)
        first.requestBegin()
        first.begin()
        clock.advance(by: 2 * hour)

        let (relaunched, _) = try makeFlow(container: container)
        relaunched.refresh()

        guard case .active(let watch) = relaunched.screen else { return XCTFail("Expected restored watch") }
        XCTAssertEqual(watch.progress(at: clock.now), 0.25)
    }

    func testRefreshAfterTargetShowsCompletion() throws {
        let (flow, _) = try makeFlow()
        flow.requestBegin()
        flow.begin()
        clock.advance(by: 9 * hour)

        flow.refresh()
        flow.refresh()

        guard case .ended(let ended) = flow.screen else { return XCTFail("Expected ended screen") }
        XCTAssertTrue(ended.completed)
        XCTAssertEqual(ended.duration, 8 * hour)
        XCTAssertEqual(haptics.played, [.completion])

        flow.dismissEnded()
        XCTAssertEqual(flow.screen, .harbour)
        flow.refresh()
        XCTAssertEqual(flow.screen, .harbour)
    }

    func testEndEarlyRecordsInterruption() throws {
        let (flow, store) = try makeFlow()
        flow.requestBegin()
        flow.begin()
        clock.advance(by: 90 * 60)

        flow.endEarly()

        guard case .ended(let ended) = flow.screen else { return XCTFail("Expected ended screen") }
        XCTAssertFalse(ended.completed)
        XCTAssertEqual(ended.duration, 90 * 60)
        XCTAssertEqual(try store.logbook().first?.status, .interrupted)
    }

    // MARK: Notifications

    func testPermissionIsNotRequestedUntilUserAsks() throws {
        let (flow, _) = try makeFlow()
        flow.requestBegin()
        flow.begin()

        XCTAssertEqual(notifications.requestCount, 0)
        XCTAssertNil(notifications.scheduledDate)
    }

    func testNotificationDenialLeavesWatchUsable() async throws {
        notifications.responseToRequest = .denied
        let (flow, store) = try makeFlow()

        await flow.setMorningNotification(true)

        XCTAssertFalse(flow.morningNotificationEnabled)
        XCTAssertEqual(flow.notificationNotice, WatchFlowModel.Copy.notificationsDenied)
        XCTAssertFalse(preferences.load().morningNotificationEnabled)

        flow.requestBegin()
        flow.begin()
        guard case .active = flow.screen else { return XCTFail("Watch must start without notifications") }
        XCTAssertNotNil(try store.activeWatch())
        XCTAssertNil(notifications.scheduledDate)
    }

    func testAllowedNotificationIsScheduledAtTargetAndCancelledOnEnd() async throws {
        let (flow, _) = try makeFlow()
        await flow.setMorningNotification(true)
        flow.requestBegin()
        flow.begin()
        await flow.notificationWork?.value

        XCTAssertEqual(notifications.scheduledDate, clock.now.addingTimeInterval(8 * hour))

        flow.endEarly()
        XCTAssertNil(notifications.scheduledDate)
    }
}

final class FaceDownDetectorTests: XCTestCase {
    func testRequiresSustainedFaceDown() {
        var detector = FaceDownDetector()
        XCTAssertFalse(detector.update(gravityZ: 0.95, at: 0))
        XCTAssertFalse(detector.update(gravityZ: 0.95, at: 0.5))
        XCTAssertTrue(detector.update(gravityZ: 0.95, at: 1.0))
    }

    func testLiftingResetsTheHold() {
        var detector = FaceDownDetector()
        _ = detector.update(gravityZ: 0.95, at: 0)
        _ = detector.update(gravityZ: 0.2, at: 0.8)
        XCTAssertFalse(detector.update(gravityZ: 0.95, at: 1.0))
        XCTAssertFalse(detector.update(gravityZ: 0.95, at: 1.9))
        XCTAssertTrue(detector.update(gravityZ: 0.95, at: 2.0))
    }

    func testFaceUpNeverTriggers() {
        var detector = FaceDownDetector()
        for step in 0..<50 {
            XCTAssertFalse(detector.update(gravityZ: -0.98, at: Double(step) * 0.1))
        }
    }
}
