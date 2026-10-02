import SwiftUI

/// A raised panel. Translucent over the scene, opaque `deepSea` with Reduce Transparency.
private struct SurfaceModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(theme.raisedBackground.opacity(reduceTransparency ? 1 : 0.78))
            }
            .overlay {
                if theme.isHighContrast {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: Metrics.hairline)
                }
            }
    }
}

extension View {
    func surface() -> some View {
        modifier(SurfaceModifier())
    }
}
