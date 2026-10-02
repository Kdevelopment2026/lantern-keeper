import SwiftUI

private struct LighthouseAmbienceEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Turns off all lighthouse animation. Used by snapshot tests for deterministic frames.
    var lighthouseAmbienceEnabled: Bool {
        get { self[LighthouseAmbienceEnabledKey.self] }
        set { self[LighthouseAmbienceEnabledKey.self] = newValue }
    }
}

/// The lighthouse with foreground ambience and an optional ignition. With Reduce Motion it
/// shows the composed still frame: static beam cone, still sea and fog.
struct AnimatedLighthouseScene: View {
    let state: LighthouseSceneState
    /// Read at the feature boundary and passed in.
    let reduceMotion: Bool
    var highContrast = false
    /// When set, the ignition plays from this moment.
    var ignitionStart: Date?

    @Environment(\.lighthouseAmbienceEnabled) private var ambienceEnabled
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false

    var body: some View {
        Group {
            if reduceMotion || !ambienceEnabled {
                LighthouseScene(state: state, highContrast: highContrast)
            } else if !isOnScreen || scenePhase != .active {
                // Off screen or locked: hold the current frame and let the timeline go.
                // Toggling `paused:` on a live TimelineView does not reliably resume on
                // every iOS version, so a fresh timeline is created on return instead.
                let (sceneState, frame) = composition(at: Date())
                LighthouseScene(state: sceneState, frame: frame, highContrast: highContrast)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let (sceneState, frame) = composition(at: context.date)
                    LighthouseScene(state: sceneState, frame: frame, highContrast: highContrast)
                }
            }
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .accessibilityHidden(true)
    }

    private func composition(at date: Date) -> (LighthouseSceneState, LighthouseFrame) {
        guard let ignitionStart, state.isBeamVisible else {
            return (state, LighthouseAmbience.frame(for: state, at: date.timeIntervalSinceReferenceDate))
        }
        // After an ignition, ambient time keeps counting from the sweep so the lens never jumps.
        let elapsed = date.timeIntervalSince(ignitionStart)
        let ambient = LighthouseAmbience.frame(for: state, at: IgnitionTimeline.ambientTime(elapsed: elapsed))
        guard !IgnitionTimeline.isComplete(elapsed: elapsed) else { return (state, ambient) }
        return (.igniting, IgnitionTimeline.frame(elapsed: elapsed, ambient: ambient))
    }
}
