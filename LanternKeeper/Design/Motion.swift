import SwiftUI

/// All timing lives here. Each animated moment has a designed Reduce Motion equivalent.
enum Motion {
    // MARK: Screen and state changes

    /// Standard change between screens and states.
    static let stateChange = Animation.easeInOut(duration: 0.45)
    /// Reduce Motion replacement for any movement: a short cross-fade.
    static let crossFade = Animation.easeInOut(duration: 0.3)

    static func stateChange(reduceMotion: Bool) -> Animation {
        reduceMotion ? crossFade : stateChange
    }

    // MARK: Ignition (the one orchestrated moment)

    static let ignitionNightSettle: TimeInterval = 0.6
    static let ignitionLanternWarm: TimeInterval = 0.9
    static let ignitionBeamSweep: TimeInterval = 1.6
    static let ignitionControlsSettle: TimeInterval = 0.5
    static var ignitionTotal: TimeInterval {
        ignitionNightSettle + ignitionLanternWarm + ignitionBeamSweep + ignitionControlsSettle
    }

    /// Reduce Motion: unlit to fully lit, as one cross-fade.
    static let ignitionReduced: TimeInterval = 0.5

    // MARK: Ambience (foreground only)

    /// Seconds for the beam to complete one slow sweep cycle.
    static let beamSweepPeriod: TimeInterval = 16
    /// Beam rest angle and sweep half-width, in degrees from horizontal (pointing left).
    static let beamRestAngle: Double = 12
    static let beamSweepAmplitude: Double = 10
    /// Seconds for the sea to drift one wavelength.
    static let seaDriftPeriod: TimeInterval = 24
    /// Seconds for fog to cross the scene once.
    static let fogDriftPeriod: TimeInterval = 90
}
