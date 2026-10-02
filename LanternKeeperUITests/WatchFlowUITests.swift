import XCTest

/// End-to-end ritual tests. Time is injected with `-uitest-now`, so nothing waits on the
/// real clock.
@MainActor
final class WatchFlowUITests: XCTestCase {
    private let night = "2026-06-10T22:42:00Z"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(now: String, reset: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-now", now] + (reset ? ["-uitest-reset"] : []) + extra
        app.launch()
        return app
    }

    private func beginWatch(_ app: XCUIApplication) {
        app.buttons["harbour.beginWatch"].tap()
        let start = app.buttons["prompt.startWithoutTurning"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.buttons["active.endWatch"].waitForExistence(timeout: 5))
    }

    func testFirstRunToFirstWatchInTwoTaps() {
        let app = launch(now: night, reset: true)
        XCTAssertTrue(app.buttons["harbour.beginWatch"].waitForExistence(timeout: 5))

        beginWatch(app)

        XCTAssertTrue(app.staticTexts["active.status"].exists || app.otherElements["active.status"].exists)
    }

    func testStartButtonIsVisibleWithoutGesture() {
        let app = launch(now: night, reset: true)
        app.buttons["harbour.beginWatch"].tap()

        let start = app.buttons["prompt.startWithoutTurning"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(app.buttons["prompt.notNow"].isHittable)

        app.buttons["prompt.notNow"].tap()
        XCTAssertTrue(app.buttons["harbour.beginWatch"].waitForExistence(timeout: 5))
    }

    func testFaceDownGestureStartsTheSameWatch() {
        let app = launch(now: night, reset: true, extra: ["-uitest-facedown-after", "1"])
        app.buttons["harbour.beginWatch"].tap()

        XCTAssertTrue(app.buttons["active.endWatch"].waitForExistence(timeout: 6))
    }

    func testReopeningDuringActiveWatchRestoresIt() {
        var app = launch(now: night, reset: true)
        beginWatch(app)
        app.terminate()

        app = launch(now: "2026-06-11T01:42:00Z")

        XCTAssertTrue(app.buttons["active.endWatch"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["harbour.beginWatch"].exists)
    }

    func testEndingEarlyAsksFirst() {
        let app = launch(now: night, reset: true)
        beginWatch(app)

        // Asking first: the dialog appears and can be dismissed without ending anything.
        app.buttons["active.endWatch"].tap()
        let confirm = app.buttons["active.confirmEnd"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        let keep = app.buttons["Keep watching"]
        if keep.exists {
            keep.tap()
        } else {
            // iOS 26 presents the dialog as a popover without a cancel button.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["active.endWatch"].exists)

        app.buttons["active.endWatch"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let summary = app.descendants(matching: .any)["ended.duration"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.hasPrefix("Watch time"))

        app.buttons["ended.done"].tap()
        XCTAssertTrue(app.buttons["harbour.beginWatch"].waitForExistence(timeout: 5))
    }

    func testMorningShowsCompletedWatch() {
        var app = launch(now: night, reset: true)
        beginWatch(app)
        app.terminate()

        app = launch(now: "2026-06-11T07:30:00Z")

        let summary = app.descendants(matching: .any)["ended.duration"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.hasPrefix("Watch kept for 8 hours"), summary.label)

        app.buttons["ended.done"].tap()
        XCTAssertTrue(app.buttons["harbour.beginWatch"].waitForExistence(timeout: 5))
    }

    func testDeniedNotificationsStillAllowAWatch() {
        let app = launch(now: night, reset: true, extra: ["-uitest-notifications-denied"])
        app.buttons["harbour.changePlan"].tap()

        let toggle = app.switches["plan.notificationToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()

        let notice = app.descendants(matching: .any)["plan.notificationNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")

        app.buttons["plan.done"].tap()
        beginWatch(app)
    }
}
