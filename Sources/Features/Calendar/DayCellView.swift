import SwiftUI

public struct DayCellView: View {
    public let date: Date
    public let inCurrentMonth: Bool
    public let presetName: String?
    public let presetColorHex: String?
    public let alarmTime: DateComponents?
    public let holidayLabel: String?

    @ScaledMetric(relativeTo: .callout) private var dotSize: CGFloat = 8

    public init(
        date: Date,
        inCurrentMonth: Bool,
        presetName: String?,
        presetColorHex: String?,
        alarmTime: DateComponents?,
        holidayLabel: String?
    ) {
        self.date = date
        self.inCurrentMonth = inCurrentMonth
        self.presetName = presetName
        self.presetColorHex = presetColorHex
        self.alarmTime = alarmTime
        self.holidayLabel = holidayLabel
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var timeString: String? {
        guard let alarmTime, let h = alarmTime.hour, let m = alarmTime.minute else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    private var accessibilityDescription: String {
        let datePart = date.formatted(Date.FormatStyle(date: .long, time: .omitted))
        var parts = [datePart]
        if let presetName { parts.append(presetName) }
        if let t = timeString {
            parts.append(String(localized: "a11y.cell.alarm_at") + " " + t)
        }
        if let holidayLabel { parts.append(holidayLabel) }
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(dayString)
                .font(.callout.monospacedDigit())
                .foregroundStyle(inCurrentMonth ? .primary : .secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityHidden(true)
            if let presetColorHex {
                Circle()
                    .fill(Color(hex: presetColorHex))
                    .frame(width: dotSize, height: dotSize)
                    .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: dotSize, height: dotSize)
                    .accessibilityHidden(true)
            }
            if let timeString {
                Text(timeString)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            } else if holidayLabel != nil {
                Text("calendar.holiday_short")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            } else {
                Text(" ")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(inCurrentMonth ? Color(.secondarySystemBackground) : Color(.systemBackground))
        )
        .opacity(inCurrentMonth ? 1.0 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
}
