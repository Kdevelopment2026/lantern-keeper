import SwiftUI
import XCTest
@testable import LanternKeeper

/// Every lighthouse state in standard, Reduce Motion and Increased Contrast, plus screens at
/// default and accessibility text sizes.
@MainActor
final class SnapshotTests: XCTestCase {
    private let states: [(String, LighthouseSceneState)] = [
        ("idle", .idle),
        ("igniting", .igniting),
        ("watching", .watching(progress: 0.4)),
        ("dawn", .dawn),
        ("interrupted", .interrupted),
    ]

    func testSceneStandard() {
        for (name, state) in states {
            assertSnapshot(scene(state, highContrast: false), named: "scene-\(name)-standard")
        }
    }

    func testSceneIncreasedContrast() {
        for (name, state) in states {
            assertSnapshot(scene(state, highContrast: true), named: "scene-\(name)-contrast")
        }
    }

    func testHarbourDefaultTextSize() throws {
        assertSnapshot(try harbour(.large), named: "harbour-large")
    }

    func testHarbourAccessibilityTextSize() throws {
        assertSnapshot(try harbour(.accessibility3), named: "harbour-accessibility3")
    }

    func testActiveWatchAtBothTextSizes() throws {
        for size in [DynamicTypeSize.large, .accessibility3] {
            let (flow, clock) = try flowWithWatch()
            clock.advance(by: 3 * hour)
            guard case .active(let watch) = flow.screen else { return XCTFail("Expected active watch") }
            assertSnapshot(
                ActiveWatchView(flow: flow, watch: watch).themed(.night).environment(\.dynamicTypeSize, size),
                named: "active-\(size == .large ? "large" : "accessibility3")"
            )
        }
    }

    func testCompletedWatchAtBothTextSizes() throws {
        for size in [DynamicTypeSize.large, .accessibility3] {
            let (flow, clock) = try flowWithWatch()
            clock.advance(by: 9 * hour)
            flow.refresh()
            guard case .ended(let ended) = flow.screen else { return XCTFail("Expected ended watch") }
            assertSnapshot(
                WatchEndedView(flow: flow, ended: ended).themed(.dawn).environment(\.dynamicTypeSize, size),
                named: "completed-\(size == .large ? "large" : "accessibility3")"
            )
        }
    }

    func testInterruptedWatch() throws {
        let (flow, clock) = try flowWithWatch()
        clock.advance(by: 2 * hour + 15 * 60)
        flow.endEarly()
        guard case .ended(let ended) = flow.screen else { return XCTFail("Expected ended watch") }
        assertSnapshot(WatchEndedView(flow: flow, ended: ended).themed(.night), named: "interrupted-large")
    }

    // MARK: Builders

    private func flowWithWatch() throws -> (WatchFlowModel, FixedClock) {
        let clock = FixedClock(date("2026-06-10T22:42:00Z"))
        let (store, _) = try makeStore(clock: clock)
        let flow = WatchFlowModel(
            store: store,
            clock: clock,
            preferences: InMemoryPreferencesStore(),
            notifications: FakeNotificationService(),
            haptics: RecordingHapticsService(),
            format: WatchFormat(calendar: .london, locale: Locale(identifier: "en_GB")),
            announce: { _ in }
        )
        flow.requestBegin()
        flow.begin()
        return (flow, clock)
    }

    private func scene(_ state: LighthouseSceneState, highContrast: Bool) -> some View {
        LighthouseScene(state: state, highContrast: highContrast)
            .ignoresSafeArea()
            .themed(state.themeVariant)
    }

    private func harbour(_ size: DynamicTypeSize) throws -> some View {
        let model = HarbourModel(
            clock: FixedClock(date("2026-06-10T22:42:00Z")),
            preferences: InMemoryPreferencesStore(),
            format: WatchFormat(calendar: .london, locale: Locale(identifier: "en_GB"))
        )
        return HarbourView(model: model)
            .themed(.night)
            .environment(\.dynamicTypeSize, size)
            .preferredColorScheme(.dark)
    }
}
