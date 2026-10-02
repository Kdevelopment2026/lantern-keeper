import Foundation

/// Values that animation may vary from frame to frame. `resting(for:)` is the designed
/// still composition used by snapshots and by Reduce Motion.
struct LighthouseFrame: Equatable, Sendable {
    /// 0 is a dark lantern, 1 is full gold.
    var lanternIntensity: Double
    /// Multiplied by the state's beam visibility, so a beam can never show when idle.
    var beamOpacity: Double
    /// Lens heading in degrees: 0 = out to sea on the left, 90 = towards the viewer,
    /// 180 = right, 270 = behind the tower. The second beam is always 180° on.
    var beamHeading: Double
    /// 0 is the idle sky, 1 is the settled night of an active watch.
    var nightDepth: Double
    /// Sea drift in wavelengths, `0..<1`.
    var seaPhase: Double
    /// Fog drift in scene widths, `0..<1`.
    var fogOffset: Double
    /// Seconds of ambient time for twinkle, flicker and bobbing. 0 in the still state.
    var tick: Double = 0

    static func resting(for state: LighthouseSceneState) -> LighthouseFrame {
        switch state {
        case .idle:
            LighthouseFrame(lanternIntensity: 0, beamOpacity: 0, beamHeading: Motion.beamRestHeading,
                            nightDepth: 0, seaPhase: 0, fogOffset: 0.2)
        case .interrupted:
            LighthouseFrame(lanternIntensity: 0.12, beamOpacity: 0, beamHeading: Motion.beamRestHeading,
                            nightDepth: 0, seaPhase: 0, fogOffset: 0.2)
        case .igniting, .watching:
            LighthouseFrame(lanternIntensity: 1, beamOpacity: 1, beamHeading: Motion.beamRestHeading,
                            nightDepth: 1, seaPhase: 0, fogOffset: 0.2)
        case .dawn:
            LighthouseFrame(lanternIntensity: 0, beamOpacity: 0, beamHeading: Motion.beamRestHeading,
                            nightDepth: 0, seaPhase: 0, fogOffset: 0.35)
        }
    }
}
