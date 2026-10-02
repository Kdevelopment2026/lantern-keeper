import SwiftUI
import UIKit
import XCTest
@testable import LanternKeeper

/// WCAG contrast checks for every semantic text and control pairing.
final class ThemeTests: XCTestCase {
    private func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func assertReadable(_ theme: Theme, file: StaticString = #filePath, line: UInt = #line) {
        let label = "\(theme.variant) highContrast=\(theme.isHighContrast)"
        XCTAssertGreaterThanOrEqual(contrast(theme.primaryText, theme.background), 7, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.primaryText, theme.raisedBackground), 7, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.secondaryText, theme.background), 4.5, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.secondaryText, theme.raisedBackground), 4.5, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.onAction, theme.action), 4.5, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.action, theme.background), 3, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.focusRing, theme.background), 3, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(contrast(theme.interrupted, theme.background), 4.5, label, file: file, line: line)
    }

    func testAllThemesMeetContrast() {
        for variant in [Theme.Variant.night, .dawn] {
            for highContrast in [false, true] {
                assertReadable(Theme.make(variant, highContrast: highContrast))
            }
        }
    }

    func testIncreasedContrastStrengthensSecondaryText() {
        let standard = Theme.make(.night, highContrast: false)
        let strong = Theme.make(.night, highContrast: true)
        XCTAssertGreaterThan(
            contrast(strong.secondaryText, strong.background),
            contrast(standard.secondaryText, standard.background)
        )
    }
}
