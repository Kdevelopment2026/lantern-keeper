import SwiftUI

/// Seven nights as marks along a shoreline. Text carries the same facts, so the row is
/// never the only record.
struct ShorelineView: View {
    let summary: ShorelineSummary
    let format: WatchFormat

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(summary.nights) { night in
                    VStack(spacing: Spacing.xxs) {
                        mark(for: night.status)
                            .frame(width: 20, height: 20)
                        Text(format.weekday(night.day))
                            .font(TypeScale.caption)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(theme.divider)
                    .frame(height: Metrics.hairline)
                    .offset(y: 10)
                    .padding(.horizontal, Spacing.xs)
                    .zIndex(-1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(spokenNights))

            Text(totalLine)
                .font(TypeScale.label)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("logbook.total")
        }
    }

    @ViewBuilder
    private func mark(for status: WatchStatus?) -> some View {
        switch status {
        case .completed:
            Image(systemName: "sailboat.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.action)
        case .interrupted:
            Circle()
                .strokeBorder(theme.interrupted, lineWidth: 1.5)
                .frame(width: 10, height: 10)
        case .active, .none:
            Circle()
                .fill(theme.divider)
                .frame(width: 5, height: 5)
        }
    }

    private var totalLine: String {
        let time = format.duration(summary.totalWatchTime)
        switch summary.completedCount {
        case 0: return String(localized: "Last seven nights: \(time) of watch time.")
        case 1: return String(localized: "Last seven nights: \(time) of watch time, 1 completed watch.")
        default: return String(localized: "Last seven nights: \(time) of watch time, \(summary.completedCount) completed watches.")
        }
    }

    private var spokenNights: String {
        let parts = summary.nights.map { night -> String in
            let day = format.weekday(night.day)
            switch night.status {
            case .completed: return String(localized: "\(day) completed")
            case .interrupted: return String(localized: "\(day) ended early")
            case .active, .none: return String(localized: "\(day) no watch")
            }
        }
        return String(localized: "Last seven nights: ") + parts.joined(separator: ", ")
    }
}
