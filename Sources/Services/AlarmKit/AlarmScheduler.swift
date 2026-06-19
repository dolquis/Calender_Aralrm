import Foundation
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class AlarmScheduler {
    private let modelContainer: ModelContainer
    private let alarmClient: any AlarmSchedulingClient
    private let saveContext: @MainActor (ModelContext) throws -> Void
    private let fetchExistingAlarms: @MainActor (ModelContext) throws -> [ShiftAlarm]

    private enum RefreshResult: String {
        case completed
        case fetchExistingAlarmsFailed
    }

    public init(
        modelContainer: ModelContainer,
        alarmClient: any AlarmSchedulingClient,
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() },
        fetchExistingAlarms: @escaping @MainActor (ModelContext) throws -> [ShiftAlarm] = {
            try $0.fetch(FetchDescriptor<ShiftAlarm>())
        }
    ) {
        self.modelContainer = modelContainer
        self.alarmClient = alarmClient
        self.saveContext = saveContext
        self.fetchExistingAlarms = fetchExistingAlarms
    }

    public convenience init(modelContainer: ModelContainer, service: AlarmService) {
        self.init(modelContainer: modelContainer, alarmClient: service)
    }

    /// One concrete alarm that the scheduler wants to be present in AlarmKit.
    /// `key` is the value used to match expected ↔ existing rows: calendar-day for wake alarms,
    /// exact fire date for bedtime reminders (two reminders may land on the same calendar day).
    private struct ExpectedAlarm {
        let key: Date
        let fireDate: Date
        let label: String
        let soundID: String
        let kind: ScheduledAlarmKind
    }

    /// Recompute the expected set of alarms for the lookahead window and reconcile with AlarmKit.
    public func refreshScheduledAlarms() async {
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let settings = loadSettings(context: context)
        let lookahead = max(1, settings.lookaheadDays)
        let days = Array(DayRange(start: .now, dayCount: lookahead, calendar: calendar))
        let existingAlarms: [ShiftAlarm]
        do {
            existingAlarms = try fetchExistingAlarms(context)
        } catch {
            // Without persisted rows, live AlarmKit IDs cannot be distinguished from real alarms.
            recordSchedulerRun(
                settings: settings,
                result: .fetchExistingAlarmsFailed,
                context: context
            )
            return
        }

        let input = await Self.buildResolverInput(context: context, calendar: calendar)
        let expectedWake = Self.buildExpectedWake(
            days: days, input: input, settings: settings, calendar: calendar)
        let expectedBedtime = Self.buildExpectedBedtime(
            days: days, input: input, settings: settings)

        await cancelOrphanedLiveAlarms(knownAlarms: existingAlarms)

        let (existingWakeByDay, existingBedtimeByFireDate) =
            Self.partitionExisting(
                existingAlarms,
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
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        recordSchedulerRun(settings: settings, result: .completed, context: context)
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
                soundID: preset?.soundID ?? settings.defaultSoundID,
                kind: .main
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
                    soundID: settings.defaultSoundID,
                    kind: .bedtime
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
                await reschedule(existingAlarm, to: entry, context: context)
            } else {
                await scheduleNew(entry, isBedtimeReminder: isBedtimeReminder, context: context)
            }
        }
        for (key, alarm) in existingByKey where !expectedKeys.contains(key) {
            await cancel(alarm, context: context)
        }
    }

    private func cancelOrphanedLiveAlarms(knownAlarms: [ShiftAlarm]) async {
        guard let liveIDs = try? await alarmClient.scheduledIDs() else { return }
        let knownIDs = Set(
            knownAlarms.flatMap { alarm -> [UUID] in
                var ids = alarm.pendingCancelIDs
                if let current = alarm.currentAlarmKitID {
                    ids.append(current)
                }
                return ids
            }
        )
        for orphanID in liveIDs.subtracting(knownIDs) {
            try? await alarmClient.cancel(id: orphanID)
        }
    }

    private func reschedule(
        _ existing: ShiftAlarm,
        to entry: ExpectedAlarm,
        context: ModelContext
    ) async {
        let needsReplacement =
            existing.fireDate != entry.fireDate
            || existing.label != entry.label
            || existing.soundID != entry.soundID
            || existing.currentAlarmKitID == nil

        guard needsReplacement else {
            await cancelPendingIDs(for: existing, context: context)
            return
        }
        let previousFireDate = existing.fireDate
        let previousLabel = existing.label
        let previousSoundID = existing.soundID
        let previousCurrentID = existing.currentAlarmKitID
        let previousPendingIDs = existing.pendingCancelIDs
        let newID = UUID()
        do {
            try await alarmClient.schedule(
                id: newID,
                fireDate: entry.fireDate,
                label: entry.label,
                soundID: entry.soundID,
                kind: entry.kind
            )
            if let previousCurrentID {
                existing.appendPendingCancelID(previousCurrentID)
            }
            existing.fireDate = entry.fireDate
            existing.label = entry.label
            existing.soundID = entry.soundID
            existing.currentAlarmKitID = newID
            do {
                try saveContext(context)
            } catch {
                existing.fireDate = previousFireDate
                existing.label = previousLabel
                existing.soundID = previousSoundID
                existing.currentAlarmKitID = previousCurrentID
                existing.pendingCancelIDs = previousPendingIDs
                try? await alarmClient.cancel(id: newID)
                return
            }
            await cancelPendingIDs(for: existing, context: context)
        } catch {
            // Schedule failed: old alarm is still active; next refresh will retry.
        }
    }

    private func scheduleNew(
        _ entry: ExpectedAlarm, isBedtimeReminder: Bool, context: ModelContext
    ) async {
        let newID = UUID()
        do {
            try await alarmClient.schedule(
                id: newID,
                fireDate: entry.fireDate,
                label: entry.label,
                soundID: entry.soundID,
                kind: entry.kind
            )
            let alarm = ShiftAlarm(
                fireDate: entry.fireDate,
                label: entry.label,
                soundID: entry.soundID,
                isEnabled: true,
                alarmKitID: newID,
                isBedtimeReminder: isBedtimeReminder
            )
            context.insert(alarm)
            do {
                try saveContext(context)
            } catch {
                context.delete(alarm)
                try? await alarmClient.cancel(id: newID)
            }
        } catch {
            // Schedule failed: skip persisting; the next refresh will retry.
        }
    }

    private func cancel(_ alarm: ShiftAlarm, context: ModelContext) async {
        if let kitID = alarm.currentAlarmKitID {
            alarm.appendPendingCancelID(kitID)
            alarm.currentAlarmKitID = nil
            do {
                try saveContext(context)
            } catch {
                return
            }
        }
        await cancelPendingIDs(for: alarm, context: context)
        if alarm.currentAlarmKitID == nil, alarm.pendingCancelIDs.isEmpty {
            context.delete(alarm)
            try? saveContext(context)
        }
    }

    private func cancelPendingIDs(for alarm: ShiftAlarm, context: ModelContext) async {
        for pendingID in alarm.pendingCancelIDs {
            do {
                try await alarmClient.cancel(id: pendingID)
                alarm.removePendingCancelID(pendingID)
                try saveContext(context)
            } catch {
                // Leave the ID in pending so the next refresh can retry.
            }
        }
    }

    private func loadSettings(context: ModelContext) -> AppSettings {
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return settings
        }
        let settings = AppSettings()
        context.insert(settings)
        try? saveContext(context)
        return settings
    }

    private func recordSchedulerRun(
        settings: AppSettings,
        result: RefreshResult,
        context: ModelContext
    ) {
        settings.lastAlarmSchedulerRunAt = .now
        settings.lastAlarmSchedulerResultRaw = result.rawValue
        try? saveContext(context)
    }

    static func buildResolverInput(
        context: ModelContext, calendar: Calendar
    ) async -> DayResolverInput {
        DayResolverInputBuilder.make(context: context, calendar: calendar)
    }
}
