import CoreMotion
import Foundation

enum OrientationEvent: Equatable, Sendable {
    /// The phone has rested face down long enough to count as intentional.
    case faceDown
    /// Turn detection cannot run on this device right now.
    case unavailable
}

/// Foreground-only face-down detection. Samples are never stored or logged.
@MainActor
protocol OrientationService: AnyObject {
    /// Starts motion updates for the lifetime of the stream. Cancelling the consuming task
    /// stops updates immediately.
    func faceDownEvents() -> AsyncStream<OrientationEvent>
}

/// Turns raw gravity readings into one debounced face-down event.
struct FaceDownDetector {
    /// Gravity on the z axis approaches +1 when the screen faces the floor.
    var threshold = 0.85
    var holdDuration: TimeInterval = 1.0
    private var faceDownSince: TimeInterval?

    mutating func update(gravityZ: Double, at timestamp: TimeInterval) -> Bool {
        guard gravityZ > threshold else {
            faceDownSince = nil
            return false
        }
        guard let since = faceDownSince else {
            faceDownSince = timestamp
            return false
        }
        return timestamp - since >= holdDuration
    }
}

@MainActor
final class MotionOrientationService: OrientationService {
    private let manager = CMMotionManager()

    func faceDownEvents() -> AsyncStream<OrientationEvent> {
        AsyncStream { continuation in
            guard manager.isDeviceMotionAvailable else {
                continuation.yield(.unavailable)
                continuation.finish()
                return
            }

            var detector = FaceDownDetector()
            manager.deviceMotionUpdateInterval = 0.1
            manager.startDeviceMotionUpdates(to: .main) { motion, error in
                guard let motion else {
                    if error != nil {
                        continuation.yield(.unavailable)
                        continuation.finish()
                    }
                    return
                }
                if detector.update(gravityZ: motion.gravity.z, at: motion.timestamp) {
                    continuation.yield(.faceDown)
                    continuation.finish()
                }
            }

            let stopper = MotionStopper(manager: manager)
            continuation.onTermination = { _ in stopper.stop() }
        }
    }
}

/// Lets the stream's termination handler stop the manager from any thread.
private final class MotionStopper: @unchecked Sendable {
    private let manager: CMMotionManager

    init(manager: CMMotionManager) {
        self.manager = manager
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

/// Simulator and test stand-in. Emits face down after a delay, or never.
@MainActor
final class FakeOrientationService: OrientationService {
    private let faceDownAfter: TimeInterval?
    private let available: Bool

    init(faceDownAfter: TimeInterval? = nil, available: Bool = true) {
        self.faceDownAfter = faceDownAfter
        self.available = available
    }

    func faceDownEvents() -> AsyncStream<OrientationEvent> {
        let delay = faceDownAfter
        let available = available
        return AsyncStream { continuation in
            guard available else {
                continuation.yield(.unavailable)
                continuation.finish()
                return
            }
            guard let delay else { return }
            let task = Task {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                continuation.yield(.faceDown)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
