import CoreGraphics

/// 4-point spacing scale.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64

    /// Side margin for screen content.
    static let screenMargin: CGFloat = 24
}

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

enum Metrics {
    static let minimumTarget: CGFloat = 44
    static let primaryButtonHeight: CGFloat = 56
    static let focusRingWidth: CGFloat = 2
    static let focusRingWidthHighContrast: CGFloat = 3
    static let hairline: CGFloat = 1
}
