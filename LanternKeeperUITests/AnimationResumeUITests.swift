import XCTest

/// The lighthouse must keep moving after the app is backgrounded and brought back
/// (locking and unlocking the phone takes the same path).
@MainActor
final class AnimationResumeUITests: XCTestCase {
    private func framesChange(_ app: XCUIApplication) -> Bool {
        let first = app.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 0.8)
        let second = app.screenshot().pngRepresentation
        return first != second
    }

    func testSceneKeepsAnimatingAfterReturningToForeground() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-reset", "-uitest-now", "2026-06-10T22:42:00Z"]
        app.launch()
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["harbour.beginWatch"].waitForExistence(timeout: 5))
        app.buttons["harbour.beginWatch"].tap()
        app.buttons["prompt.startWithoutTurning"].tap()
        XCTAssertTrue(app.buttons["active.endWatch"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 5) // let the ignition finish
        XCTAssertTrue(framesChange(app), "scene should animate before backgrounding")

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.activate()
        XCTAssertTrue(app.buttons["active.endWatch"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)

        XCTAssertTrue(framesChange(app), "scene should still animate after returning to the foreground")
    }
}
