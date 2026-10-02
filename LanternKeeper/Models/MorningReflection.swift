import Foundation

/// An optional, non-clinical morning note. Skipping stores no value.
enum MorningReflection: String, Codable, CaseIterable, Sendable {
    case clear
    case steady
    case tired
}
