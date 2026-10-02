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

final class LighthouseMotionTests: XCTestCase {
    func testAmbienceIsDeterministicAndBounded() {
        for time in stride(from: 0.0, through: 120, by: 0.7) {
            let frame = LighthouseAmbience.frame(for: .watching(progress: 0.5), at: time)
            XCTAssertEqual(frame, LighthouseAmbience.frame(for: .watching(progress: 0.5), at: time))
            XCTAssertLessThanOrEqual(abs(frame.beamAngle - Motion.beamRestAngle), Motion.beamSweepAmplitude + 1e-9)
            XCTAssertTrue((0..<1).contains(frame.seaPhase))
            XCTAssertTrue((0..<1).contains(frame.fogOffset))
        }
    }

    func testIdleAmbienceNeverLightsTheLantern() {
        for time in stride(from: 0.0, through: 60, by: 1.3) {
            let frame = LighthouseAmbience.frame(for: .idle, at: time)
            XCTAssertEqual(frame.lanternIntensity, 0)
            XCTAssertEqual(frame.beamOpacity, 0)
        }
    }

    func testIgnitionOrder() {
        let ambient = LighthouseAmbience.frame(for: .watching(progress: 0), at: 0)

        let start = IgnitionTimeline.frame(elapsed: 0, ambient: ambient)
        XCTAssertEqual(start.nightDepth, 0)
        XCTAssertEqual(start.lanternIntensity, 0)
        XCTAssertEqual(start.beamOpacity, 0)

        // Night settles before the lantern warms; the lantern is full before the sweep.
        let settled = IgnitionTimeline.frame(elapsed: IgnitionTimeline.lanternStart, ambient: ambient)
        XCTAssertEqual(settled.nightDepth, 1, accuracy: 1e-9)
        XCTAssertEqual(settled.lanternIntensity, 0, accuracy: 1e-9)

        let warmed = IgnitionTimeline.frame(elapsed: IgnitionTimeline.sweepStart, ambient: ambient)
        XCTAssertEqual(warmed.lanternIntensity, 1, accuracy: 1e-9)
        XCTAssertEqual(warmed.beamOpacity, 0, accuracy: 1e-9)
        XCTAssertEqual(warmed.beamAngle, IgnitionTimeline.sweepStartAngle, accuracy: 1e-9)

        let done = IgnitionTimeline.frame(elapsed: IgnitionTimeline.sweepEnd, ambient: ambient)
        XCTAssertEqual(done.beamAngle, ambient.beamAngle, accuracy: 1e-9)
        XCTAssertEqual(done.beamOpacity, ambient.beamOpacity, accuracy: 1e-9)
        XCTAssertTrue(IgnitionTimeline.isComplete(elapsed: IgnitionTimeline.sweepEnd))
    }

    func testLanternWarmsMonotonically() {
        let ambient = LighthouseFrame.resting(for: .watching(progress: 0))
        var previous = -1.0
        for step in 0...40 {
            let elapsed = IgnitionTimeline.sweepEnd * Double(step) / 40
            let intensity = IgnitionTimeline.frame(elapsed: elapsed, ambient: ambient).lanternIntensity
            XCTAssertGreaterThanOrEqual(intensity, previous)
            previous = intensity
        }
    }
}
