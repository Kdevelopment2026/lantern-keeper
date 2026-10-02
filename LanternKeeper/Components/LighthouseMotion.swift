import Foundation

/// Slow foreground ambience: beam sweep, sea drift, rare fog. A pure function of time, so
/// any frame can be reproduced exactly.
enum LighthouseAmbience {
    static func frame(for state: LighthouseSceneState, at time: TimeInterval) -> LighthouseFrame {
        var frame = LighthouseFrame.resting(for: state)
        frame.seaPhase = (time / Motion.seaDriftPeriod).truncatingRemainder(dividingBy: 1)
        frame.fogOffset = (0.2 + time / Motion.fogDriftPeriod).truncatingRemainder(dividingBy: 1)
        if state.isBeamVisible {
            frame.beamAngle = Motion.beamRestAngle
                + Motion.beamSweepAmplitude * sin(2 * .pi * time / Motion.beamSweepPeriod)
        }
        return frame
    }
}

/// The one orchestrated moment: night settles, the lantern warms, the beam sweeps once.
/// Haptic and controls follow (driven by the view at `hapticTime`).
enum IgnitionTimeline {
    static let sweepStartAngle: Double = 38

    static var lanternStart: TimeInterval { Motion.ignitionNightSettle }
    static var sweepStart: TimeInterval { lanternStart + Motion.ignitionLanternWarm }
    static var sweepEnd: TimeInterval { sweepStart + Motion.ignitionBeamSweep }
    static var hapticTime: TimeInterval { sweepEnd }

    static func isComplete(elapsed: TimeInterval) -> Bool {
        elapsed >= sweepEnd
    }

    /// Blends from the unlit harbour into `ambient`, arriving exactly at `ambient` when done.
    static func frame(elapsed: TimeInterval, ambient: LighthouseFrame) -> LighthouseFrame {
        var frame = ambient
        frame.nightDepth = ambient.nightDepth * ease(phase(elapsed, from: 0, to: lanternStart))
        frame.lanternIntensity = ambient.lanternIntensity * ease(phase(elapsed, from: lanternStart, to: sweepStart))
        let sweep = phase(elapsed, from: sweepStart, to: sweepEnd)
        frame.beamOpacity = ambient.beamOpacity * ease(min(1, sweep * 3))
        frame.beamAngle = sweepStartAngle + (ambient.beamAngle - sweepStartAngle) * ease(sweep)
        return frame
    }

    private static func phase(_ elapsed: TimeInterval, from start: TimeInterval, to end: TimeInterval) -> Double {
        guard end > start else { return elapsed >= end ? 1 : 0 }
        return min(1, max(0, (elapsed - start) / (end - start)))
    }

    /// Smoothstep: gentle in, gentle out.
    private static func ease(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }
}
