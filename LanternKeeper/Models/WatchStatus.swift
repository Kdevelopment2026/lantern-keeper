import Foundation

enum WatchStatus: String, Codable, CaseIterable, Sendable {
    case active
    case completed
    case interrupted
}
