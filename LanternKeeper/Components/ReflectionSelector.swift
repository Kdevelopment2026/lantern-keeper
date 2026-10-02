import SwiftUI

extension MorningReflection {
    var title: LocalizedStringKey {
        switch self {
        case .clear: "Clear"
        case .steady: "Steady"
        case .tired: "Tired"
        }
    }

    var spokenTitle: String {
        switch self {
        case .clear: String(localized: "Clear")
        case .steady: String(localized: "Steady")
        case .tired: String(localized: "Tired")
        }
    }
}

/// Optional, plain-language morning reflection. Tapping the chosen one again clears it.
struct ReflectionSelector: View {
    @Binding var selection: MorningReflection?

    @Environment(\.theme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) { options }
            VStack(alignment: .leading, spacing: Spacing.xs) { options }
        }
    }

    private var options: some View {
        ForEach(MorningReflection.allCases, id: \.self) { reflection in
            let isSelected = selection == reflection
            Button {
                selection = isSelected ? nil : reflection
            } label: {
                Text(reflection.title)
                    .font(TypeScale.body)
                    .foregroundStyle(isSelected ? theme.onAction : theme.primaryText)
                    .padding(.horizontal, Spacing.m)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget)
                    .background(Capsule().fill(isSelected ? theme.action : .clear))
                    .overlay(Capsule().strokeBorder(
                        isSelected ? theme.action : theme.divider,
                        lineWidth: theme.isHighContrast ? Metrics.focusRingWidthHighContrast : Metrics.hairline
                    ))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityIdentifier("reflection.\(reflection.rawValue)")
        }
    }
}
