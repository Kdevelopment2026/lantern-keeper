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

    // MARK: Builders

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
