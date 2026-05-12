import Foundation
import SwiftData
import WidgetKit

public struct NextAlarmEntry: TimelineEntry {
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
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let refreshAfter: Date = entry.fireDate.map { $0.addingTimeInterval(60) } ?? Date(timeIntervalSinceNow: 60 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(refreshAfter))
            completion(timeline)
        }
    }

    @MainActor
    private func fetchEntry() async -> NextAlarmEntry {
        let container = SharedPersistence.makeContainer()
        let context = ModelContext(container)
        let alarms: [ShiftAlarm] = (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
        let next = alarms
            .filter { $0.isEnabled && $0.fireDate > .now }
            .sorted { $0.fireDate < $1.fireDate }
            .first
        let presetID = next?.assignment?.preset?.id
        let preset: ShiftPreset? = presetID.flatMap { id in
            (try? context.fetch(FetchDescriptor<ShiftPreset>()))?.first { $0.id == id }
        }
        return NextAlarmEntry(
            date: .now,
            fireDate: next?.fireDate,
            presetName: preset?.name ?? next?.label,
            colorHex: preset?.colorHex
        )
    }
}
