import SwiftUI

/// Three short pages. Skip is always visible; no permission is requested here.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page {
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(
            title: "The scroll can end here.",
            body: "Late at night, one more video becomes another lost hour. Lantern Keeper gives that moment a gentler ending: begin a watch, put the phone down, and let the light stay on."
        ),
        Page(
            title: "Set the watch.",
            body: "Choose how long to keep watch, then turn your phone face down. The watch runs on the clock, so it continues while the screen is locked. It doesn’t block other apps; it keeps the time you chose."
        ),
        Page(
            title: "Morning, not metrics.",
            body: "In the morning you’ll see the time you kept, and can add a word about how you feel. Lantern Keeper measures time away from your phone, never sleep. Nothing leaves this device."
        ),
    ]

    var body: some View {
        let isLast = page == pages.count - 1
        ScreenScaffold {
            AnimatedLighthouseScene(state: .idle, reduceMotion: reduceMotion, highContrast: theme.isHighContrast)
        } top: {
            HStack(alignment: .center) {
                pageIndicator
                Spacer()
                QuietActionButton("Skip", action: onFinish)
                    .accessibilityIdentifier("onboarding.skip")
            }
        } bottom: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(pages[page].title)
                    .font(TypeScale.reflectiveHeading)
                    .foregroundStyle(theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(pages[page].body)
                    .font(TypeScale.body)
                    .foregroundStyle(theme.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .id(page)
            .transition(.opacity)
            .accessibilityIdentifier("onboarding.page\(page)")

            PrimaryActionButton(isLast ? "Begin" : "Next") {
                if isLast {
                    onFinish()
                } else {
                    withAnimation(Motion.stateChange(reduceMotion: reduceMotion)) { page += 1 }
                }
            }
            .accessibilityIdentifier(isLast ? "onboarding.begin" : "onboarding.next")

            if page > 0 {
                QuietActionButton("Back") {
                    withAnimation(Motion.stateChange(reduceMotion: reduceMotion)) { page -= 1 }
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? theme.action : theme.divider)
                    .frame(width: index == page ? 20 : 8, height: 8)
            }
        }
        .frame(minHeight: Metrics.minimumTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(page + 1) of \(pages.count)"))
    }
}
