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

    /// Recompute the expected set of alarms for the lookahead window and reconcile with AlarmKit.
    public func refreshScheduledAlarms() async {
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        let lookahead = max(1, settings.lookaheadDays)
        let range = DayRange(start: .now, dayCount: lookahead, calendar: calendar)
        let days = Array(range)

        let input = await Self.buildResolverInput(context: context, calendar: calendar)

        // --- Wake alarms ---
        var expectedWake: [(date: Date, fireDate: Date, label: String, soundID: String)] = []
        for day in days {
            let resolved = DayResolver.resolve(date: day, input: input)
            guard !resolved.skipsAlarm, let fireTime = resolved.fireTime,
                  let hour = fireTime.hour, let minute = fireTime.minute,
                  let fireDate = day.combining(hour: hour, minute: minute, in: calendar),
                  fireDate > .now else { continue }
            let presetID = resolved.presetID
            let label = presetID.flatMap { input.presets[$0]?.name } ?? String(localized: "alarm.default_label")
            let soundID = presetID.flatMap { input.presets[$0]?.soundID } ?? settings.defaultSoundID
            expectedWake.append((date: day, fireDate: fireDate, label: label, soundID: soundID))
        }

        // --- Bedtime reminders ---
        let sleepWindows = SleepWindowResolver.resolve(dates: days, input: input)
        var expectedBedtime: [(date: Date, fireDate: Date, label: String, soundID: String)] = []
        for window in sleepWindows {
            guard let reminderDate = window.reminderFireDate, reminderDate > .now else { continue }
            let label = "\(String(localized: "sleep.reminder_label")) \(window.presetName)"
            // Key by the reminder's own calendar day, not the wake day. For a 10pm reminder before
            // a 6am wake, the reminder fires the previous calendar day, so the keys must match.
            expectedBedtime.append((
                date: calendar.startOfDay(for: reminderDate),
                fireDate: reminderDate,
                label: label,
                soundID: settings.defaultSoundID
            ))
        }

        let existing: [ShiftAlarm] = (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
        var existingWakeByDay: [Date: ShiftAlarm] = [:]
        var existingBedtimeByDay: [Date: ShiftAlarm] = [:]
        for alarm in existing {
            let dayKey = calendar.startOfDay(for: alarm.fireDate)
            if alarm.isBedtimeReminder {
                existingBedtimeByDay[dayKey] = alarm
            } else {
                existingWakeByDay[dayKey] = alarm
            }
        }

        var expectedWakeDays = Set<Date>()
        for entry in expectedWake { expectedWakeDays.insert(entry.date) }
        var expectedBedtimeDays = Set<Date>()
        for entry in expectedBedtime { expectedBedtimeDays.insert(entry.date) }

        await diffSync(
            expected: expectedWake,
            existingByDay: existingWakeByDay,
            expectedDays: expectedWakeDays,
            isBedtimeReminder: false,
            context: context
        )
        await diffSync(
            expected: expectedBedtime,
            existingByDay: existingBedtimeByDay,
            expectedDays: expectedBedtimeDays,
            isBedtimeReminder: true,
            context: context
        )

        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func diffSync(
        expected: [(date: Date, fireDate: Date, label: String, soundID: String)],
        existingByDay: [Date: ShiftAlarm],
        expectedDays: Set<Date>,
        isBedtimeReminder: Bool,
        context: ModelContext
    ) async {
        for entry in expected {
            if let existingAlarm = existingByDay[entry.date] {
                if existingAlarm.fireDate != entry.fireDate
                    || existingAlarm.label != entry.label
                    || existingAlarm.soundID != entry.soundID {
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
                        if let kitID = existingAlarm.alarmKitID {
                            try? await service.cancel(id: kitID)
                        }
                        existingAlarm.fireDate = entry.fireDate
                        existingAlarm.label = entry.label
                        existingAlarm.soundID = entry.soundID
                        existingAlarm.alarmKitID = newID
                    } catch {
                        // Schedule failed: old alarm is still active; next refresh will retry.
                    }
                }
            } else {
                let newID = UUID()
                do {
                    try await service.schedule(
                        id: newID,
                        fireDate: entry.fireDate,
                        label: entry.label,
                        soundID: entry.soundID
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
                } catch {
                    // Schedule failed: skip persisting; the next refresh will retry.
                }
            }
        }

        for (day, alarm) in existingByDay where !expectedDays.contains(day) {
            if let kitID = alarm.alarmKitID {
                do {
                    try await service.cancel(id: kitID)
                } catch {
                    // Cancel failed; leave the DB row so the next refresh can retry.
                    continue
                }
            }
            context.delete(alarm)
        }
    }

    static func buildResolverInput(context: ModelContext, calendar: Calendar) async -> DayResolverInput {
        let presets: [ShiftPreset] = (try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        let assignments: [DayAssignment] = (try? context.fetch(FetchDescriptor<DayAssignment>())) ?? []
        let holidays: [HolidayOverride] = (try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? []
        let rotations: [RotationPattern] = (try? context.fetch(FetchDescriptor<RotationPattern>())) ?? []

        let presetSnapshots: [UUID: ShiftPresetSnapshot] = presets.reduce(into: [:]) { acc, p in
            acc[p.id] = ShiftPresetSnapshot(
                id: p.id,
                name: p.name,
                colorHex: p.colorHex,
                alarmTime: p.defaultAlarmTime,
                soundID: p.soundID,
                targetSleepDuration: p.targetSleepDuration,
                bedtimeLeadMinutes: p.bedtimeLeadMinutes
            )
        }

        let assignmentSnapshots: [Date: DayAssignmentSnapshot] = assignments.reduce(into: [:]) { acc, a in
            acc[calendar.startOfDay(for: a.date)] = DayAssignmentSnapshot(
                presetID: a.preset?.id,
                overrideTime: a.overrideAlarmTime,
                skipAlarm: a.skipAlarm,
                note: a.note
            )
        }

        let holidaySnapshots: [Date: HolidayOverrideSnapshot] = holidays.reduce(into: [:]) { acc, h in
            acc[calendar.startOfDay(for: h.date)] = HolidayOverrideSnapshot(
                label: h.label,
                skipAlarm: h.skipAlarm,
                replacementPresetID: h.replacementPreset?.id
            )
        }

        let rotationSnapshots = rotations.map { r in
            RotationPatternSnapshot(
                id: r.id,
                name: r.name,
                anchorDate: r.anchorDate,
                cycleLength: r.cycleLength,
                slots: r.slots,
                startDate: r.startDate,
                endDate: r.endDate,
                priority: r.priority,
                isActive: r.isActive
            )
        }

        return DayResolverInput(
            manualAssignments: assignmentSnapshots,
            holidays: holidaySnapshots,
            rotations: rotationSnapshots,
            presets: presetSnapshots,
            calendar: calendar
        )
    }
}
