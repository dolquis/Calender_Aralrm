import SwiftUI
import WidgetKit

@main
struct ShiftAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()
        #if canImport(ActivityKit)
        ShiftAlarmLiveActivity()
        #endif
    }
}
