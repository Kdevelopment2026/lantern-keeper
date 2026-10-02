import SwiftUI

/// Every style scales with Dynamic Type.
enum TypeScale {
    /// New York: the product name.
    static let wordmark = Font.system(.largeTitle, design: .serif)
    /// New York: reflective and morning headings.
    static let reflectiveHeading = Font.system(.title, design: .serif)

    /// SF Pro: interface text.
    static let title = Font.title2.weight(.semibold)
    static let body = Font.body
    static let label = Font.subheadline
    static let caption = Font.footnote
    static let button = Font.headline

    /// SF Mono: times and durations.
    static let timeDisplay = Font.system(.largeTitle, design: .monospaced).weight(.light).monospacedDigit()
    static let time = Font.system(.title2, design: .monospaced).monospacedDigit()
    static let timeSmall = Font.system(.body, design: .monospaced).monospacedDigit()
}
