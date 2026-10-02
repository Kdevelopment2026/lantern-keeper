import Foundation

struct UserPreferences: Equatable, Codable, Sendable {
    var lastPlan: WatchPlan = .default
    var hapticsEnabled = true
    var morningNotificationEnabled = false
    var onboardingCompleted = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case lastPlan, hapticsEnabled, morningNotificationEnabled, onboardingCompleted
    }

    /// Missing keys keep their defaults, so adding a preference never discards stored ones.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastPlan = try container.decodeIfPresent(WatchPlan.self, forKey: .lastPlan) ?? .default
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        morningNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .morningNotificationEnabled) ?? false
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
    }
}
