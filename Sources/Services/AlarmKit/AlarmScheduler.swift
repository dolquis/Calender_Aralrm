import Foundation
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class AlarmScheduler {
    private let modelContainer: ModelContainer
    private let service: AlarmService

    public init(modelContainer: ModelContainer, service: AlarmService) {
        self.modelContainer = modelContainer
        self.service = service
    }

    /// One concrete alarm that the scheduler wants to be present in AlarmKit.
    /// `key` is the value used to match expected ↔ existing rows: calendar-day for wake alarms,
    /// exact fire date for bedtime reminders (two reminders may land on the same calendar day).
    private struct ExpectedAlarm {
        let key: Date
        let fireDate: Date
        let label: String
        let soundID: String
    }

    /// Recompute the expected set of alarms for the lookahead window and reconcile with AlarmKit.
    public func refreshScheduledAlarms() async {
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        let lookahead = max(1, settings.lookaheadDays)
        let days = Array(DayRange(start: .now, dayCount: lookahead, calendar: calendar))

        let input = await Self.buildResolverInput(context: context, calendar: calendar)
        let expectedWake = Self.buildExpectedWake(
            days: days, input: input, settings: settings, calendar: calendar)
        let expectedBedtime = Self.buildExpectedBedtime(
            days: days, input: input, settings: settings)

        let (existingWakeByDay, existingBedtimeByFireDate) = Self.partitionExisting(
            (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? [],
            calendar: calendar
        )

        await diffSync(
            expected: expectedWake,
            existingByKey: existingWakeByDay,
            isBedtimeReminder: false,
            context: context
        )
        await diffSync(
            expected: expectedBedtime,
            existingByKey: existingBedtimeByFireDate,
            isBedtimeReminder: true,
            context: context
        )

        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Expected-set construction

    private static func buildExpectedWake(
        days: [Date],
        input: DayResolverInput,
        settings: AppSettings,
        calendar: Calendar
    ) -> [ExpectedAlarm] {
        days.compactMap { day in
            let resolved = DayResolver.resolve(date: day, input: input)
            guard !resolved.skipsAlarm,
                let fireTime = resolved.fireTime,
                let hour = fireTime.hour,
                let minute = fireTime.minute,
                let fireDate = day.combining(hour: hour, minute: minute, in: calendar),
                fireDate > .now
            else { return nil }
            let preset = resolved.presetID.flatMap { input.presets[$0] }
            return ExpectedAlarm(
                key: day,
                fireDate: fireDate,
                label: preset?.name ?? String(localized: "alarm.default_label"),
                soundID: preset?.soundID ?? settings.defaultSoundID
            )
        }
    }

    private static func buildExpectedBedtime(
        days: [Date],
        input: DayResolverInput,
        settings: AppSettings
    ) -> [ExpectedAlarm] {
        // Filter to future wake times only; SleepWindowResolver itself no longer does this
        // so that it can also serve historical writes for HealthKit.
        SleepWindowResolver.resolve(dates: days, input: input)
            .filter { $0.wakeTime > .now }
            .compactMap { window in
                guard let reminderDate = window.reminderFireDate, reminderDate > .now else {
                    return nil
                }
                // Key by the exact fire date so two reminders that fall on the same calendar day
                // (e.g., afternoon-wake + next-day early-wake) never collide.
                return ExpectedAlarm(
                    key: reminderDate,
                    fireDate: reminderDate,
                    label: "\(String(localized: "sleep.reminder_label")) \(window.presetName)",
                    soundID: settings.defaultSoundID
                )
            }
    }

    private static func partitionExisting(
        _ alarms: [ShiftAlarm],
        calendar: Calendar
    ) -> (wakeByDay: [Date: ShiftAlarm], bedtimeByFireDate: [Date: ShiftAlarm]) {
        var wakeByDay: [Date: ShiftAlarm] = [:]
        var bedtimeByFireDate: [Date: ShiftAlarm] = [:]
        for alarm in alarms {
            if alarm.isBedtimeReminder {
                bedtimeByFireDate[alarm.fireDate] = alarm
            } else {
                wakeByDay[calendar.startOfDay(for: alarm.fireDate)] = alarm
            }
        }
        return (wakeByDay, bedtimeByFireDate)
    }

    // MARK: - Diff-sync

    private func diffSync(
        expected: [ExpectedAlarm],
        existingByKey: [Date: ShiftAlarm],
        isBedtimeReminder: Bool,
        context: ModelContext
    ) async {
        let expectedKeys = Set(expected.map(\.key))
        for entry in expected {
            if let existingAlarm = existingByKey[entry.key] {
                await reschedule(existingAlarm, to: entry)
            } else {
                await scheduleNew(entry, isBedtimeReminder: isBedtimeReminder, context: context)
            }
        }
        for (key, alarm) in existingByKey where !expectedKeys.contains(key) {
            await cancel(alarm, context: context)
        }
    }

    private func reschedule(_ existing: ShiftAlarm, to entry: ExpectedAlarm) async {
        guard
            existing.fireDate != entry.fireDate
                || existing.label != entry.label
                || existing.soundID != entry.soundID
        else { return }
        let newID = UUID()
        do {
            try await service.schedule(
                id: newID,
                fireDate: entry.fireDate,
                label: entry.label,
                soundID: entry.soundID
            )
            // Cancel old alarm only after the replacement is confirmed scheduled,
            // so a transient failure never leaves the user with no active alarm.
            if let kitID = existing.alarmKitID {
                try? await service.cancel(id: kitID)
            }
            existing.fireDate = entry.fireDate
            existing.label = entry.label
            existing.soundID = entry.soundID
            existing.alarmKitID = newID
        } catch {
            // Schedule failed: old alarm is still active; next refresh will retry.
        }
    }

    private func scheduleNew(
        _ entry: ExpectedAlarm, isBedtimeReminder: Bool, context: ModelContext
    ) async {
        let newID = UUID()
        do {
            try await service.schedule(
                id: newID,
                fireDate: entry.fireDate,
                label: entry.label,
                soundID: entry.soundID
            )
            context.insert(
                ShiftAlarm(
                    fireDate: entry.fireDate,
                    label: entry.label,
                    soundID: entry.soundID,
                    isEnabled: true,
                    alarmKitID: newID,
                    isBedtimeReminder: isBedtimeReminder
                ))
        } catch {
            // Schedule failed: skip persisting; the next refresh will retry.
        }
    }

    private func cancel(_ alarm: ShiftAlarm, context: ModelContext) async {
        if let kitID = alarm.alarmKitID {
            do {
                try await service.cancel(id: kitID)
            } catch {
                // Cancel failed; leave the DB row so the next refresh can retry.
                return
            }
        }
        context.delete(alarm)
    }

    static func buildResolverInput(
        context: ModelContext, calendar: Calendar
    ) async -> DayResolverInput {
        DayResolverInputBuilder.make(context: context, calendar: calendar)
    }
}
