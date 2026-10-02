import SwiftUI

/// Chooses a watch by length or by end time. Length is the default path.
struct DurationPicker: View {
    @Binding var plan: WatchPlan
    let format: WatchFormat
    let now: Date

    static let step: TimeInterval = 30 * 60
    static let range: ClosedRange<TimeInterval> = 3600...(12 * 3600)

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Mode: Hashable {
        case duration
        case endTime
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            modePicker

            switch plan {
            case .duration(let interval):
                durationControl(interval)
            case .endTime(let hour, let minute):
                endTimeControl(hour: hour, minute: minute)
            }

            if let end = try? plan.targetEnd(from: now, calendar: format.calendar) {
                Text("Ends at \(format.time(end))")
                    .font(TypeScale.label)
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityIdentifier("plan.endsAt")
            }
        }
    }

    // MARK: Mode

    @ViewBuilder
    private var modePicker: some View {
        let picker = Picker("Set watch by", selection: modeBinding) {
            Text("Length").tag(Mode.duration)
            Text("End time").tag(Mode.endTime)
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu).tint(theme.primaryText)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private var modeBinding: Binding<Mode> {
        Binding {
            if case .duration = plan { .duration } else { .endTime }
        } set: { mode in
            switch (mode, plan) {
            case (.endTime, .duration(let interval)):
                let end = now.addingTimeInterval(interval)
                let parts = format.calendar.dateComponents([.hour, .minute], from: end)
                plan = .endTime(hour: parts.hour ?? 7, minute: parts.minute ?? 0)
            case (.duration, .endTime):
                let end = (try? plan.targetEnd(from: now, calendar: format.calendar)) ?? now.addingTimeInterval(8 * 3600)
                plan = .duration(Self.snap(end.timeIntervalSince(now)))
            default:
                break
            }
        }
    }

    // MARK: Duration

    private func durationControl(_ interval: TimeInterval) -> some View {
        HStack(spacing: Spacing.m) {
            stepButton(systemImage: "minus", label: "Shorter", enabled: interval > Self.range.lowerBound) {
                plan = .duration(Self.snap(interval - Self.step))
            }
            Text(format.duration(interval))
                .font(TypeScale.time)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            stepButton(systemImage: "plus", label: "Longer", enabled: interval < Self.range.upperBound) {
                plan = .duration(Self.snap(interval + Self.step))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Watch length"))
        .accessibilityValue(Text(format.spokenDuration(interval)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: plan = .duration(Self.snap(interval + Self.step))
            case .decrement: plan = .duration(Self.snap(interval - Self.step))
            @unknown default: break
            }
        }
        .accessibilityIdentifier("plan.duration")
    }

    private func stepButton(systemImage: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(TypeScale.button)
                .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                .overlay(Circle().strokeBorder(theme.divider, lineWidth: Metrics.hairline))
                .contentShape(Circle())
        }
        .foregroundStyle(theme.primaryText)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(Text(label))
    }

    static func snap(_ interval: TimeInterval) -> TimeInterval {
        let snapped = (interval / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }

    // MARK: End time

    private func endTimeControl(hour: Int, minute: Int) -> some View {
        let binding = Binding<Date> {
            format.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        } set: { date in
            let parts = format.calendar.dateComponents([.hour, .minute], from: date)
            plan = .endTime(hour: parts.hour ?? hour, minute: parts.minute ?? minute)
        }
        return DatePicker("End time", selection: binding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .environment(\.timeZone, format.calendar.timeZone)
            .environment(\.calendar, format.calendar)
            .accessibilityLabel(Text("End time"))
            .accessibilityIdentifier("plan.endTime")
    }
}
