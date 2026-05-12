import SwiftUI
import WidgetKit

public struct NextAlarmWidgetView: View {
    public let entry: NextAlarmEntry
    @Environment(\.widgetFamily) private var family

    public init(entry: NextAlarmEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            standard
        }
    }

    @ViewBuilder
    private var standard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let hex = entry.colorHex {
                    Circle().fill(Color(hex: hex)).frame(width: 10, height: 10)
                }
                Text(entry.presetName ?? "widget.no_alarm_title")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            if let fire = entry.fireDate {
                Text(fire, style: .time)
                    .font(.title.bold())
                    .monospacedDigit()
                Text(fire, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("widget.no_alarm_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var rectangular: some View {
        VStack(alignment: .leading) {
            Text(entry.presetName ?? "widget.no_alarm_title")
                .font(.caption.weight(.semibold))
            if let fire = entry.fireDate {
                Text(fire, style: .time)
                    .font(.body.bold().monospacedDigit())
                Text(fire, style: .relative)
                    .font(.caption2)
            } else {
                Text("widget.no_alarm_subtitle")
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private var circular: some View {
        if let fire = entry.fireDate {
            VStack(spacing: 0) {
                Text(fire, style: .time)
                    .font(.caption2.bold().monospacedDigit())
            }
        } else {
            Image(systemName: "alarm.fill")
        }
    }
}
