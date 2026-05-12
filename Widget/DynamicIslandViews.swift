import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif
import WidgetKit

#if canImport(ActivityKit)
public struct ShiftAlarmLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftAlarmAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: context.state.colorHex))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(Color(hex: context.state.colorHex))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.fireDate, style: .timer)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.presetName)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.fireDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Circle().fill(Color(hex: context.state.colorHex)).frame(width: 12, height: 12)
            } compactTrailing: {
                Text(context.state.fireDate, style: .timer)
                    .monospacedDigit()
            } minimal: {
                Text(context.state.fireDate, style: .timer)
                    .monospacedDigit()
            }
        }
    }
}

private struct LockScreenView: View {
    let state: ShiftAlarmAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: state.colorHex)).frame(width: 14, height: 14)
                Text(state.presetName)
                    .font(.headline)
            }
            HStack {
                Text(state.fireDate, style: .time)
                    .font(.largeTitle.bold().monospacedDigit())
                Spacer()
                Text(state.fireDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
#endif
