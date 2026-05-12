import SwiftUI
import WidgetKit

public struct NextAlarmWidget: Widget {
    public let kind: String = "NextAlarmWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextAlarmTimelineProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.display_name")
        .description("widget.description")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
        ])
    }
}
