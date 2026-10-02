import SwiftUI

/// Full-bleed scene behind content that scrolls only when it needs to (for example at
/// accessibility text sizes). A scrim keeps text legible over the scene.
struct ScreenScaffold<Background: View, Top: View, Bottom: View>: View {
    @ViewBuilder var background: Background
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: Bottom

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            scrim
                .ignoresSafeArea()
                .accessibilityHidden(true)

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        top
                        Spacer(minLength: Spacing.xxl)
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            bottom
                        }
                    }
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.l)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(theme.background)
    }

    @ViewBuilder
    private var scrim: some View {
        if dynamicTypeSize.isAccessibilitySize || reduceTransparency {
            // Large text can reach the tower, so the whole scene sits back.
            theme.background.opacity(reduceTransparency ? 0.9 : 0.72)
        } else {
            LinearGradient(
                stops: [
                    .init(color: theme.background.opacity(0), location: 0.45),
                    .init(color: theme.background.opacity(0.8), location: 0.68),
                    .init(color: theme.background.opacity(0.92), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
