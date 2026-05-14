import Foundation
import SwiftData

/// Shared helper for App Intents that need to compute sleep windows from the store.
@MainActor
enum SleepIntentHelper {
    static func fetchUpcomingWindows(lookahead: Int = 14) async -> [SleepWindowEntity] {
        let container = SharedPersistence.makeContainer()
        let context = ModelContext(container)
        let calendar = Calendar.current
        let input = await AlarmScheduler.buildResolverInput(context: context, calendar: calendar)
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        let days = Array(DayRange(start: .now, dayCount: min(lookahead, settings.lookaheadDays), calendar: calendar))
        let windows = SleepWindowResolver.resolve(dates: days, input: input)
        return windows.map { w in
            SleepWindowEntity(
                id: w.date.ISO8601Format(),
                wakeTime: w.wakeTime,
                bedtime: w.bedtime,
                presetName: w.presetName
            )
        }
    }

    static func fetchNextWindow() async -> SleepWindowEntity? {
        await fetchUpcomingWindows(lookahead: 7).first
    }
}
