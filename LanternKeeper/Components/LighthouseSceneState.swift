import Foundation

/// The only input that decides what the lighthouse shows.
enum LighthouseSceneState: Equatable, Sendable {
    case idle
    case igniting
    case watching(progress: Double)
    case dawn
    case interrupted

    /// Watch progress clamped to `0...1`, or `nil` when no watch is running.
    var progress: Double? {
        guard case .watching(let progress) = self else { return nil }
        guard progress.isFinite else { return 0 }
        return min(1, max(0, progress))
    }

    var isBeamVisible: Bool {
        switch self {
        case .igniting, .watching: true
        case .idle, .dawn, .interrupted: false
        }
    }

    var isLanternLit: Bool { isBeamVisible }

    var showsShip: Bool { self == .dawn }

    var themeVariant: Theme.Variant { self == .dawn ? .dawn : .night }
}
