import Foundation
import SwiftData

/// Builds `DayResolverInput` snapshots from SwiftData models.
///
/// Centralising this conversion keeps the calendar UI and the AlarmKit scheduler in
/// lockstep so sleep-related fields on `ShiftPreset` (target sleep duration, bedtime
/// lead minutes) cannot silently drop out of one code path.
public enum DayResolverInputBuilder {
    @MainActor
    public static func make(
        presets: [ShiftPreset],
        assignments: [DayAssignment],
        holidays: [HolidayOverride],
        rotations: [RotationPattern],
        vacations: [VacationPeriod] = [],
        swapRecords: [SwapRecord] = [],
        calendar: Calendar
    ) -> DayResolverInput {
        let presetSnapshots: [UUID: ShiftPresetSnapshot] = presets.reduce(into: [:]) {
            acc, preset in
            acc[preset.id] = ShiftPresetSnapshot(
                id: preset.id,
                name: preset.name,
                colorHex: preset.colorHex,
                alarmTime: preset.defaultAlarmTime,
                soundID: preset.soundID,
                targetSleepDuration: preset.targetSleepDuration,
                bedtimeLeadMinutes: preset.bedtimeLeadMinutes,
                crossVacationPolicy: preset.crossVacationPolicy
            )
        }

        let assignmentSnapshots: [Date: DayAssignmentSnapshot] = assignments.reduce(into: [:]) {
            acc, assignment in
            acc[calendar.startOfDay(for: assignment.date)] = DayAssignmentSnapshot(
                presetID: assignment.preset?.id,
                overrideTime: assignment.overrideAlarmTime,
                skipAlarm: assignment.skipAlarm,
                note: assignment.note
            )
        }

        let holidaySnapshots: [Date: HolidayOverrideSnapshot] = holidays.reduce(into: [:]) {
            acc, holiday in
            acc[calendar.startOfDay(for: holiday.date)] = HolidayOverrideSnapshot(
                label: holiday.label,
                skipAlarm: holiday.skipAlarm,
                replacementPresetID: holiday.replacementPreset?.id
            )
        }

        let rotationSnapshots = rotations.map { rotation in
            RotationPatternSnapshot(
                id: rotation.id,
                name: rotation.name,
                anchorDate: rotation.anchorDate,
                cycleLength: rotation.cycleLength,
                slots: rotation.slots,
                startDate: rotation.startDate,
                endDate: rotation.endDate,
                priority: rotation.priority,
                isActive: rotation.isActive,
                crossVacationPolicy: rotation.crossVacationPolicy,
                dayStartSlotIndex: rotation.dayStartSlotIndex
            )
        }

        let vacationSnapshots = vacations.map { vacation in
            VacationPeriodSnapshot(
                startDate: calendar.startOfDay(for: vacation.startDate),
                endDate: calendar.startOfDay(for: vacation.endDate),
                label: vacation.label
            )
        }

        let swapSnapshots: [Date: [SwapRecordSnapshot]] = swapRecords.reduce(into: [:]) {
            acc, swap in
            let day = calendar.startOfDay(for: swap.date)
            acc[day, default: []].append(
                SwapRecordSnapshot(
                    id: swap.id,
                    date: day,
                    kind: swap.kind,
                    counterpartyLabel: swap.counterpartyLabel,
                    note: swap.note,
                    createdAt: swap.createdAt
                ))
        }

        return DayResolverInput(
            manualAssignments: assignmentSnapshots,
            holidays: holidaySnapshots,
            rotations: rotationSnapshots,
            presets: presetSnapshots,
            vacations: vacationSnapshots,
            swapRecords: swapSnapshots,
            calendar: calendar
        )
    }

    @MainActor
    public static func make(context: ModelContext, calendar: Calendar) -> DayResolverInput {
        let presets: [ShiftPreset] = (try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        let assignments: [DayAssignment] =
            (try? context.fetch(FetchDescriptor<DayAssignment>())) ?? []
        let holidays: [HolidayOverride] =
            (try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? []
        let rotations: [RotationPattern] =
            (try? context.fetch(FetchDescriptor<RotationPattern>())) ?? []
        let vacations: [VacationPeriod] =
            (try? context.fetch(FetchDescriptor<VacationPeriod>())) ?? []
        let swapRecords: [SwapRecord] =
            (try? context.fetch(FetchDescriptor<SwapRecord>())) ?? []
        return make(
            presets: presets,
            assignments: assignments,
            holidays: holidays,
            rotations: rotations,
            vacations: vacations,
            swapRecords: swapRecords,
            calendar: calendar
        )
    }
}
