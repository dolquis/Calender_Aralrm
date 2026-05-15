import Foundation
import SwiftData

/// Shared helper for App Intents that need to compute sleep windows from the store.
@MainActor
enum SleepIntentHelper {
    /// Container factory injection point. Tests can override this to point at an in-memory store
    /// without having to mock the whole intent helper.
    static var containerFactory: @MainActor () -> ModelContainer = {
        SharedPersistence.makeContainer()
    }

    /// `lookahead` overrides the configured horizon when > 0; pass 0 (the default) to use the
    /// app's configured `lookaheadDays` so sparse schedules never return a false "no window".
    static func fetchUpcomingWindows(lookahead: Int = 0, now: Date = .now) async -> [SleepWindowEntity] {
        let container = containerFactory()
        let context = ModelContext(container)
        let calendar = Calendar.current
        let input = await AlarmScheduler.buildResolverInput(context: context, calendar: calendar)
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        let horizon = lookahead > 0 ? lookahead : settings.lookaheadDays
        let days = Array(DayRange(start: now, dayCount: horizon, calendar: calendar))
        return SleepWindowResolver.resolve(dates: days, input: input)
            .filter { $0.wakeTime > now }
            .map { window in
                SleepWindowEntity(
                    id: window.date.ISO8601Format(),
                    wakeTime: window.wakeTime,
                    bedtime: window.bedtime,
                    presetName: window.presetName
                )
            }
    }

    static func fetchNextWindow() async -> SleepWindowEntity? {
        // Use the full configured lookahead so sparse schedules (long rest stretches)
        // still return a result rather than reporting noUpcomingWindow.
        await fetchUpcomingWindows().first
    }

    /// Returns the first window whose bedtime is still in the future.
    /// Use this for the GetNextBedtimeIntent so a window whose wake time is upcoming
    /// but whose bedtime has already passed is never returned as "next bedtime."
    static func fetchNextBedtimeWindow(now: Date = .now) async -> SleepWindowEntity? {
        await fetchUpcomingWindows(now: now).first { $0.bedtime > now }
    }
}
