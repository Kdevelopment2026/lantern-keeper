import Foundation

/// Slow foreground ambience: beam sweep, sea drift, rare fog. A pure function of time, so
/// any frame can be reproduced exactly.
enum LighthouseAmbience {
    static func frame(for state: LighthouseSceneState, at time: TimeInterval) -> LighthouseFrame {
        var frame = LighthouseFrame.resting(for: state)
        frame.tick = time
        frame.seaPhase = unitCycle(time / Motion.seaDriftPeriod)
        frame.fogOffset = unitCycle(0.2 + time / Motion.fogDriftPeriod)
        if state.isBeamVisible {
            // Constant rotation, like a real lens. `time` may be negative during ignition.
            let turns = time / Motion.beamRotationPeriod
            var heading = (turns * 360).truncatingRemainder(dividingBy: 360)
            if heading < 0 { heading += 360 }
            if heading >= 360 { heading -= 360 }
            frame.beamHeading = heading
        }
        return frame
    }
}

/// Wraps any value into `0..<1`, including negative ambient time before an ignition.
private func unitCycle(_ value: Double) -> Double {
    var cycle = value.truncatingRemainder(dividingBy: 1)
    if cycle < 0 { cycle += 1 }
    if cycle >= 1 { cycle -= 1 }
    return cycle
}

/// The one orchestrated moment: night settles, the lantern warms, the lens starts turning
/// and the beam sweeps round to its first flash towards the viewer. The haptic lands on the
/// flash and the controls follow (driven by the view at `hapticTime`).
enum IgnitionTimeline {
    /// Heading when the beam first appears: out to sea on the left.
    static let sweepStartHeading: Double = 0
    /// Heading at the end of the sweep: the first flash, straight at the viewer.
    static let sweepEndHeading: Double = 90

    /// Ambient time at which the lens is at `sweepStartHeading`, so the ambient rotation and
    /// the ignition sweep are one continuous motion.
    static func ambientTime(elapsed: TimeInterval) -> TimeInterval {
        elapsed - sweepStart
    }

    static var lanternStart: TimeInterval { Motion.ignitionNightSettle }
    static var sweepStart: TimeInterval { lanternStart + Motion.ignitionLanternWarm }
    static var sweepEnd: TimeInterval { sweepStart + Motion.ignitionBeamSweep }
    static var hapticTime: TimeInterval { sweepEnd }

    static func isComplete(elapsed: TimeInterval) -> Bool {
        elapsed >= sweepEnd
    }

    /// Blends from the unlit harbour into `ambient`, arriving exactly at `ambient` when done.
    /// `ambient` must be sampled at `ambientTime(elapsed:)` so the heading is continuous.
    static func frame(elapsed: TimeInterval, ambient: LighthouseFrame) -> LighthouseFrame {
        var frame = ambient
        frame.nightDepth = ambient.nightDepth * ease(phase(elapsed, from: 0, to: lanternStart))
        frame.lanternIntensity = ambient.lanternIntensity * ease(phase(elapsed, from: lanternStart, to: sweepStart))
        let sweep = phase(elapsed, from: sweepStart, to: sweepEnd)
        frame.beamOpacity = ambient.beamOpacity * ease(min(1, sweep * 4))
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
