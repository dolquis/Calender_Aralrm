import AppIntents
import Foundation

/// App Entity exposed to Shortcuts so automations can act on computed sleep windows.
public struct SleepWindowEntity: AppEntity, Sendable {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "睡眠ウィンドウ")
    }

    public static let defaultQuery = SleepWindowEntityQuery()

    public var id: String
    public var wakeTime: Date
    public var bedtime: Date
    public var presetName: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(presetName)",
            subtitle:
                "\(bedtime.formatted(date: .omitted, time: .shortened)) → \(wakeTime.formatted(date: .omitted, time: .shortened))"
        )
    }

    public init(id: String, wakeTime: Date, bedtime: Date, presetName: String) {
        self.id = id
        self.wakeTime = wakeTime
        self.bedtime = bedtime
        self.presetName = presetName
    }
}

public struct SleepWindowEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SleepWindowEntity] {
        let windows = await SleepIntentHelper.fetchUpcomingWindows()
        return windows.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [SleepWindowEntity] {
        await SleepIntentHelper.fetchUpcomingWindows()
    }
}
