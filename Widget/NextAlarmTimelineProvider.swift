import Foundation
import SwiftData
import WidgetKit

public struct NextAlarmEntry: TimelineEntry, Sendable {
    public let date: Date
    public let fireDate: Date?
    public let presetName: String?
    public let colorHex: String?

    public init(date: Date, fireDate: Date?, presetName: String?, colorHex: String?) {
        self.date = date
        self.fireDate = fireDate
        self.presetName = presetName
        self.colorHex = colorHex
    }

    public static let placeholder = NextAlarmEntry(
        date: .now,
        fireDate: Calendar.current.date(byAdding: .hour, value: 8, to: .now),
        presetName: "夜勤",
        colorHex: "#1E88E5"
    )
}

public struct NextAlarmTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> NextAlarmEntry {
        .placeholder
    }

    public func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        completion(Self.currentEntry())
    }

    /// Builds a multi-entry timeline so that:
    /// - The widget transitions automatically when an alarm fires.
    /// - A T-2h checkpoint entry is inserted for alarms more than 2 h away,
    ///   so WidgetKit can pick up any last-minute changes the user made.
    /// - Policy: reload after the last covered alarm plus a small buffer.
    public func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let now = Date.now
        let (alarms, presets) = Self.fetchData()

        let upcoming = alarms
            .filter { $0.isEnabled && !$0.isBedtimeReminder && $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }

        guard !upcoming.isEmpty else {
            let entry = NextAlarmEntry(date: now, fireDate: nil, presetName: nil, colorHex: nil)
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600)))
            completion(timeline)
            return
        }

        // Limit to the next 8 alarms so we stay within the ~25-entry WidgetKit budget.
        let covered = Array(upcoming.prefix(8))
        var entries: [NextAlarmEntry] = []
        var windowStart = now

        for alarm in covered {
            let preset = presets.first { $0.id == alarm.assignment?.preset?.id }

            // Always add an entry at the start of this window.
            entries.append(makeEntry(date: windowStart, alarm: alarm, preset: preset))

            // Insert a T-2h checkpoint if the alarm is still far away.
            // This lets WidgetKit reload and reflect any edits the user made.
            let twoHoursBefore = alarm.fireDate.addingTimeInterval(-2 * 3600)
            if twoHoursBefore > windowStart.addingTimeInterval(600) {
                entries.append(makeEntry(date: twoHoursBefore, alarm: alarm, preset: preset))
            }

            // Transition: 60 s after this alarm fires, the widget shows the next alarm.
            windowStart = alarm.fireDate.addingTimeInterval(60)
        }

        // After the last covered alarm, show the next uncovered alarm (if any) or "no alarm".
        let remainder = upcoming.dropFirst(covered.count)
        if let nextAlarm = remainder.first {
            let preset = presets.first { $0.id == nextAlarm.assignment?.preset?.id }
            entries.append(makeEntry(date: windowStart, alarm: nextAlarm, preset: preset))
        } else {
            entries.append(NextAlarmEntry(date: windowStart, fireDate: nil, presetName: nil, colorHex: nil))
        }

        // Reload policy: 5 min after the last covered alarm fires.
        let reloadDate = covered.last!.fireDate.addingTimeInterval(5 * 60)
        let timeline = Timeline(entries: entries, policy: .after(reloadDate))
        completion(timeline)
    }

    // MARK: - Helpers

    private static func currentEntry() -> NextAlarmEntry {
        let now = Date.now
        let (alarms, presets) = fetchData()
        let next = alarms
            .filter { $0.isEnabled && !$0.isBedtimeReminder && $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .first
        let preset: ShiftPreset? = next.flatMap { alarm in
            presets.first { $0.id == alarm.assignment?.preset?.id }
        }
        return NextAlarmEntry(
            date: now,
            fireDate: next?.fireDate,
            presetName: preset?.name ?? next?.label,
            colorHex: preset?.colorHex
        )
    }

    private static func fetchData() -> ([ShiftAlarm], [ShiftPreset]) {
        let container = SharedPersistence.makeContainer()
        let ctx = ModelContext(container)
        let alarms: [ShiftAlarm] = (try? ctx.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
        let presets: [ShiftPreset] = (try? ctx.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        return (alarms, presets)
    }

    private func makeEntry(date: Date, alarm: ShiftAlarm, preset: ShiftPreset?) -> NextAlarmEntry {
        NextAlarmEntry(
            date: date,
            fireDate: alarm.fireDate,
            presetName: preset?.name ?? alarm.label,
            colorHex: preset?.colorHex
        )
    }
}
