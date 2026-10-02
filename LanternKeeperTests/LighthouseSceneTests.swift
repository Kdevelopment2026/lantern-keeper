import XCTest
@testable import LanternKeeper

final class LighthouseSceneStateTests: XCTestCase {
    func testProgressIsClamped() {
        XCTAssertEqual(LighthouseSceneState.watching(progress: -0.5).progress, 0)
        XCTAssertEqual(LighthouseSceneState.watching(progress: 0.4).progress, 0.4)
        XCTAssertEqual(LighthouseSceneState.watching(progress: 3).progress, 1)
        XCTAssertEqual(LighthouseSceneState.watching(progress: .nan).progress, 0)
        XCTAssertNil(LighthouseSceneState.idle.progress)
    }

    func testBeamVisibleOnlyWhileIgnitingOrWatching() {
        XCTAssertTrue(LighthouseSceneState.igniting.isBeamVisible)
        XCTAssertTrue(LighthouseSceneState.watching(progress: 0.5).isBeamVisible)
        XCTAssertFalse(LighthouseSceneState.idle.isBeamVisible)
        XCTAssertFalse(LighthouseSceneState.dawn.isBeamVisible)
        XCTAssertFalse(LighthouseSceneState.interrupted.isBeamVisible)
    }

    func testRestingFramesMatchState() {
        XCTAssertEqual(LighthouseFrame.resting(for: .idle).lanternIntensity, 0)
        XCTAssertEqual(LighthouseFrame.resting(for: .watching(progress: 0.2)).lanternIntensity, 1)
        XCTAssertEqual(LighthouseFrame.resting(for: .dawn).beamOpacity, 0)
    }

    func testOnlyDawnShowsShipAndDawnPalette() {
        XCTAssertTrue(LighthouseSceneState.dawn.showsShip)
        XCTAssertEqual(LighthouseSceneState.dawn.themeVariant, .dawn)
        XCTAssertEqual(LighthouseSceneState.interrupted.themeVariant, .night)
    }

    func testAccessibilityLabelsDescribeState() {
        XCTAssertEqual(
            WatchStatusText.accessibilityLabel(for: .watching(progress: 0.1), endTime: "7:00 AM"),
            "Lighthouse lit. Watch ends at 7:00 AM."
        )
        XCTAssertEqual(WatchStatusText.accessibilityLabel(for: .idle, endTime: nil), "Lighthouse dark. No watch is active.")
        XCTAssertEqual(WatchStatusText.accessibilityLabel(for: .interrupted, endTime: nil), "Lighthouse dark. Watch ended early.")
    }
}

final class WatchFormatTests: XCTestCase {
    private let format = WatchFormat(calendar: .london, locale: Locale(identifier: "en_GB"))

    func testTimeUsesCalendarTimeZone() {
        // 06:00 UTC is 07:00 in British Summer Time and 06:00 in winter.
        XCTAssertTrue(format.time(date("2026-06-11T06:00:00Z")).hasPrefix("7:00") || format.time(date("2026-06-11T06:00:00Z")).hasPrefix("07:00"))
        XCTAssertTrue(format.time(date("2026-01-11T06:00:00Z")).hasPrefix("6:00") || format.time(date("2026-01-11T06:00:00Z")).hasPrefix("06:00"))
    }

    func testDurationRoundsDownToMinutes() {
        XCTAssertEqual(format.duration(7 * hour + 42 * 60 + 59), "7 hrs, 42 min")
        XCTAssertEqual(format.duration(8 * hour), "8 hrs")
        XCTAssertEqual(format.spokenDuration(7 * hour + 42 * 60), "7 hours, 42 minutes")
    }

    func testRemainingRoundsUp() {
        XCTAssertEqual(format.remaining(30), "1 min")
        XCTAssertEqual(format.remaining(5 * hour + 11 * 60 + 1), "5 hrs, 12 min")
    }
}
