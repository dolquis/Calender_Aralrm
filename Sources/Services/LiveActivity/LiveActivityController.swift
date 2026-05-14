import Foundation
import SwiftData
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
public final class LiveActivityController {
    private let modelContainer: ModelContainer
    private var currentActivityID: String?
    private var currentAlarmID: UUID?

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Evaluate whether an "upcoming alarm" Live Activity should be running.
    public func evaluate() async {
        #if canImport(ActivityKit)
        let context = ModelContext(modelContainer)
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        let lead = TimeInterval(settings.liveActivityLeadHours) * 3600
        let alarms: [ShiftAlarm] = (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
        let upcoming = alarms
            .filter { $0.isEnabled && !$0.isBedtimeReminder && $0.fireDate > Date() }
            .sorted { $0.fireDate < $1.fireDate }
            .first

        guard let next = upcoming else {
            await endAll()
            return
        }
        let interval = next.fireDate.timeIntervalSinceNow
        guard interval > 0 && interval <= lead else {
            await endAll()
            return
        }

        let presetName = next.label
        let colorHex = "#1E88E5"
        let state = ShiftAlarmAttributes.ContentState(
            fireDate: next.fireDate,
            presetName: presetName,
            colorHex: colorHex
        )
        let content = ActivityContent(state: state, staleDate: next.fireDate)

        if currentAlarmID == next.id, let id = currentActivityID,
           await Self.updateActivity(id: id, content: content) {
            return
        }
        await endAll()
        do {
            currentActivityID = try Self.requestActivity(alarmID: next.id, content: content)
            currentAlarmID = next.id
        } catch {
            // Live Activity request can fail when disabled by user; ignore.
        }
        #endif
    }

    public func endAll() async {
        #if canImport(ActivityKit)
        await Self.endActivities()
        currentActivityID = nil
        currentAlarmID = nil
        #endif
    }

    #if canImport(ActivityKit)
    private nonisolated static func updateActivity(
        id: String,
        content: ActivityContent<ShiftAlarmAttributes.ContentState>
    ) async -> Bool {
        guard let activity = Activity<ShiftAlarmAttributes>.activities.first(where: { $0.id == id }) else {
            return false
        }
        await activity.update(content)
        return true
    }

    private nonisolated static func requestActivity(
        alarmID: UUID,
        content: ActivityContent<ShiftAlarmAttributes.ContentState>
    ) throws -> String {
        let activity = try Activity<ShiftAlarmAttributes>.request(
            attributes: ShiftAlarmAttributes(alarmID: alarmID),
            content: content,
            pushType: nil
        )
        return activity.id
    }

    private nonisolated static func endActivities() async {
        for activity in Activity<ShiftAlarmAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    #endif
}
