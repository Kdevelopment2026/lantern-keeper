import Foundation

struct UserPreferences: Equatable, Codable, Sendable {
    var lastPlan: WatchPlan = .default
    var hapticsEnabled = true
    var morningNotificationEnabled = false
}
