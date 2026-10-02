import CoreHaptics
import Foundation

enum HapticEvent: Sendable {
    case ignition
    case selection
    case completion
}

@MainActor
protocol HapticsService: AnyObject {
    func play(_ event: HapticEvent)
}

/// Restrained single taps. Silent when the user turns haptics off or the device has none.
@MainActor
final class CoreHapticsService: HapticsService {
    private let isEnabled: @MainActor () -> Bool
    private var engine: CHHapticEngine?

    init(isEnabled: @escaping @MainActor () -> Bool) {
        self.isEnabled = isEnabled
    }

    func play(_ event: HapticEvent) {
        guard isEnabled(), CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try engine ?? makeEngine()
            try engine.start()
            let player = try engine.makePlayer(with: pattern(for: event))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil
        }
    }

    private func makeEngine() throws -> CHHapticEngine {
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        self.engine = engine
        return engine
    }

    private func pattern(for event: HapticEvent) throws -> CHHapticPattern {
        let (intensity, sharpness): (Float, Float) = switch event {
        case .ignition: (0.6, 0.3)
        case .selection: (0.35, 0.5)
        case .completion: (0.45, 0.2)
        }
        let tap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        return try CHHapticPattern(events: [tap], parameters: [])
    }
}

@MainActor
final class RecordingHapticsService: HapticsService {
    private(set) var played: [HapticEvent] = []

    func play(_ event: HapticEvent) {
        played.append(event)
    }
}
