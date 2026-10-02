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
    static let ignitionBeamSweep: TimeInterval = 3.0
    static let ignitionControlsSettle: TimeInterval = 0.5

    // MARK: Ambience (foreground only)

    /// Seconds for one full turn of the lens. Two opposite beams, so a flash every half turn.
    static let beamRotationPeriod: TimeInterval = 12
    /// Where the lens rests in the Reduce Motion still state: degrees around the lantern,
    /// 0 = out to sea on the left, 90 = towards the viewer, 180 = right, 270 = behind.
    static let beamRestHeading: Double = 25
    /// Seconds for the sea to drift one wavelength.
    static let seaDriftPeriod: TimeInterval = 9
    /// Seconds for fog to cross the scene once.
    static let fogDriftPeriod: TimeInterval = 45
}
