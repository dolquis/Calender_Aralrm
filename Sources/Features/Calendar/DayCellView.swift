import SwiftUI

public struct DayCellView: View {
    public let date: Date
    public let inCurrentMonth: Bool
    public let isToday: Bool
    public let presetName: String?
    public let presetColorHex: String?
    public let alarmTime: DateComponents?
    public let holidayLabel: String?
    public let hasSwapRecord: Bool
    public let calendar: Calendar

    public init(
        date: Date,
        inCurrentMonth: Bool,
        isToday: Bool = false,
        presetName: String?,
        presetColorHex: String?,
        alarmTime: DateComponents?,
        holidayLabel: String?,
        hasSwapRecord: Bool = false,
        calendar: Calendar = .current
    ) {
        self.date = date
        self.inCurrentMonth = inCurrentMonth
        self.isToday = isToday
        self.presetName = presetName
        self.presetColorHex = presetColorHex
        self.alarmTime = alarmTime
        self.holidayLabel = holidayLabel
        self.hasSwapRecord = hasSwapRecord
        self.calendar = calendar
    }

    private var dayString: String {
        "\(calendar.component(.day, from: date))"
    }

    private var weekday: Int {
        calendar.component(.weekday, from: date)
    }

    private var timeString: String? {
        guard let alarmTime, let h = alarmTime.hour, let m = alarmTime.minute else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    /// Sunday and holidays are red, Saturday is blue, following the
    /// Japanese calendar convention. Today wins with the accent tint.
    private var dayNumberStyle: AnyShapeStyle {
        guard inCurrentMonth else { return AnyShapeStyle(.secondary) }
        if isToday { return AnyShapeStyle(.tint) }
        if holidayLabel != nil || weekday == 1 { return AnyShapeStyle(.red) }
        if weekday == 7 { return AnyShapeStyle(.blue) }
        return AnyShapeStyle(.primary)
    }

    @ViewBuilder private var dayNumberText: some View {
        Text(dayString)
            .font(.callout.monospacedDigit().weight(isToday ? .bold : .regular))
            .foregroundStyle(dayNumberStyle)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var holidayBadge: some View {
        if holidayLabel != nil {
            StatusPill("calendar.holiday_short", tint: .red)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityDescription: String {
        let datePart = date.formatted(Date.FormatStyle(date: .long, time: .omitted))
        var parts: [String] = []
        if isToday { parts.append(String(localized: "a11y.cell.today")) }
        parts.append(datePart)
        if let presetName { parts.append(presetName) }
        if let t = timeString {
            parts.append(String(localized: "a11y.cell.alarm_at") + " " + t)
        }
        if let holidayLabel { parts.append(holidayLabel) }
        if hasSwapRecord { parts.append(String(localized: "a11y.cell.swap_recorded")) }
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Day number and holiday badge sit side by side when there is
            // room, and stack vertically at large Dynamic Type sizes so the
            // badge is never dropped just because it no longer fits on one line.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 2) {
                    dayNumberText
                    holidayBadge
                }
                VStack(spacing: 2) {
                    dayNumberText
                    holidayBadge
                }
            }
            PresetColorDot(colorHex: presetColorHex)
            HStack(spacing: 2) {
                if hasSwapRecord {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                if let timeString {
                    Text(timeString)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                } else if !hasSwapRecord {
                    Text(" ")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(inCurrentMonth ? Color(.secondarySystemBackground) : Color(.systemBackground))
        )
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.tint, lineWidth: 2)
            }
        }
        .opacity(inCurrentMonth ? 1.0 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
}
