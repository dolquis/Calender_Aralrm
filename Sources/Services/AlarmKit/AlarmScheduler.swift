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

        let input = await Self.buildResolverInput(context: context, calendar: calendar)
        var expected: [(date: Date, fireDate: Date, label: String, soundID: String, presetID: UUID?)] = []

        for day in range {
            let resolved = DayResolver.resolve(date: day, input: input)
            guard !resolved.skipsAlarm, let fireTime = resolved.fireTime,
                  let hour = fireTime.hour, let minute = fireTime.minute,
                  let fireDate = day.combining(hour: hour, minute: minute, in: calendar),
                  fireDate > .now else { continue }
            let presetID = resolved.presetID
            let label = presetID.flatMap { input.presets[$0]?.name } ?? String(localized: "alarm.default_label")
            let soundID = presetID.flatMap { input.presets[$0]?.soundID } ?? settings.defaultSoundID
            expected.append((date: day, fireDate: fireDate, label: label, soundID: soundID, presetID: presetID))
        }

        let existing: [ShiftAlarm] = (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
        var existingByDay: [Date: ShiftAlarm] = [:]
        for alarm in existing {
            existingByDay[calendar.startOfDay(for: alarm.fireDate)] = alarm
        }
        var expectedDays = Set<Date>()
        for entry in expected { expectedDays.insert(entry.date) }

        for entry in expected {
            if let existingAlarm = existingByDay[entry.date] {
                if existingAlarm.fireDate != entry.fireDate
                    || existingAlarm.label != entry.label
                    || existingAlarm.soundID != entry.soundID {
                    if let kitID = existingAlarm.alarmKitID {
                        try? await service.cancel(id: kitID)
                    }
                    let newID = UUID()
                    try? await service.schedule(
                        id: newID,
                        fireDate: entry.fireDate,
                        label: entry.label,
                        soundID: entry.soundID
                    )
                    existingAlarm.fireDate = entry.fireDate
                    existingAlarm.label = entry.label
                    existingAlarm.soundID = entry.soundID
                    existingAlarm.alarmKitID = newID
                }
            } else {
                let newID = UUID()
                try? await service.schedule(
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
                    alarmKitID: newID
                )
                context.insert(alarm)
            }
        }

        for (day, alarm) in existingByDay where !expectedDays.contains(day) {
            if let kitID = alarm.alarmKitID {
                try? await service.cancel(id: kitID)
            }
            context.delete(alarm)
        }

        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
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
                soundID: p.soundID
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
