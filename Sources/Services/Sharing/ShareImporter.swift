import Foundation
import SwiftData

public struct ImportPreview: Sendable {
    public var addedPresets: Int
    public var updatedPresets: Int
    public var addedPatterns: Int
    public var updatedPatterns: Int
    public var addedAssignments: Int
    public var updatedAssignments: Int
    public var addedOverrides: Int
    public var updatedOverrides: Int
    public var validation: ShiftBundleValidationResult = .valid

    public var hasChanges: Bool {
        addedPresets + updatedPresets + addedPatterns + updatedPatterns + addedAssignments
            + updatedAssignments + addedOverrides + updatedOverrides > 0
    }

    public var canApply: Bool {
        hasChanges && validation.isValid
    }
}

@MainActor
public enum ShareImporter {
    public static func preview(
        bundle: ShiftBundle, container: ModelContainer, calendar: Calendar = .current
    ) -> ImportPreview {
        let validation = ShiftBundleValidator.validate(bundle)
        let context = ModelContext(container)
        let existingPresets: [UUID: ShiftPreset] =
            ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let existingPatterns: [UUID: RotationPattern] =
            ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let existingAssignments: [Date: DayAssignment] =
            ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        let existingOverrides: [Date: HolidayOverride] =
            ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }

        var p = ImportPreview(
            addedPresets: 0, updatedPresets: 0,
            addedPatterns: 0, updatedPatterns: 0,
            addedAssignments: 0, updatedAssignments: 0,
            addedOverrides: 0, updatedOverrides: 0
        )
        for preset in bundle.presets {
            if existingPresets[preset.id] == nil {
                p.addedPresets += 1
            } else {
                p.updatedPresets += 1
            }
        }
        for pattern in bundle.patterns {
            if existingPatterns[pattern.id] == nil {
                p.addedPatterns += 1
            } else {
                p.updatedPatterns += 1
            }
        }
        for assignment in bundle.assignments {
            guard let day = assignment.date.date(in: calendar) else { continue }
            if existingAssignments[day] == nil {
                p.addedAssignments += 1
            } else {
                p.updatedAssignments += 1
            }
        }
        for override in bundle.overrides {
            guard let day = override.date.date(in: calendar) else { continue }
            if existingOverrides[day] == nil {
                p.addedOverrides += 1
            } else {
                p.updatedOverrides += 1
            }
        }
        p.validation = validation
        return p
    }

    public static func apply(
        bundle: ShiftBundle, container: ModelContainer, calendar: Calendar = .current
    ) throws {
        let validation = ShiftBundleValidator.validate(bundle)
        guard validation.isValid else {
            throw ShiftBundleValidationError(result: validation)
        }
        let context = ModelContext(container)
        let presets = applyPresets(bundle.presets, context: context)
        applyPatterns(bundle.patterns, context: context, calendar: calendar)
        applyAssignments(bundle.assignments, presets: presets, context: context, calendar: calendar)
        applyOverrides(bundle.overrides, presets: presets, context: context, calendar: calendar)
        try context.save()
    }

    // MARK: - Apply helpers

    private static func applyPresets(
        _ presets: [ShiftBundle.PresetDTO], context: ModelContext
    ) -> [UUID: ShiftPreset] {
        var byID: [UUID: ShiftPreset] = ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        for p in presets {
            let colorHex = ShiftBundleValidator.normalizedColorHex(p.colorHex)
            if let existing = byID[p.id] {
                existing.name = p.name
                existing.colorHex = colorHex
                existing.defaultAlarmHour = p.defaultAlarmHour
                existing.defaultAlarmMinute = p.defaultAlarmMinute
                existing.soundID = p.soundID
                existing.note = p.note
            } else {
                let new = ShiftPreset(
                    id: p.id,
                    name: p.name,
                    colorHex: colorHex,
                    defaultAlarmHour: p.defaultAlarmHour,
                    defaultAlarmMinute: p.defaultAlarmMinute,
                    soundID: p.soundID,
                    note: p.note
                )
                context.insert(new)
                byID[p.id] = new
            }
        }
        return byID
    }

    private static func applyPatterns(
        _ patterns: [ShiftBundle.RotationDTO], context: ModelContext, calendar: Calendar
    ) {
        var byID: [UUID: RotationPattern] =
            ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        for r in patterns {
            guard let anchor = r.anchorDate.date(in: calendar) else { continue }
            let start = r.startDate?.date(in: calendar)
            let end = r.endDate?.date(in: calendar)
            if let existing = byID[r.id] {
                existing.name = r.name
                existing.anchorDate = anchor
                existing.cycleLength = r.cycleLength
                existing.slots = r.slots
                existing.startDate = start
                existing.endDate = end
                existing.priority = r.priority
                existing.isActive = r.isActive
            } else {
                let new = RotationPattern(
                    id: r.id,
                    name: r.name,
                    anchorDate: anchor,
                    cycleLength: r.cycleLength,
                    slots: r.slots,
                    startDate: start,
                    endDate: end,
                    priority: r.priority,
                    isActive: r.isActive
                )
                context.insert(new)
                byID[r.id] = new
            }
        }
    }

    private static func applyAssignments(
        _ assignments: [ShiftBundle.AssignmentDTO],
        presets: [UUID: ShiftPreset],
        context: ModelContext,
        calendar: Calendar
    ) {
        var byDay: [Date: DayAssignment] =
            ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        var seen = Set(byDay.keys)
        for a in assignments {
            guard let day = a.date.date(in: calendar) else { continue }
            let preset = a.presetID.flatMap { presets[$0] }
            if let existing = byDay[day] {
                existing.preset = preset
                existing.overrideAlarmHour = a.overrideAlarmHour
                existing.overrideAlarmMinute = a.overrideAlarmMinute
                existing.skipAlarm = a.skipAlarm
                existing.note = a.note
            } else if !seen.contains(day) {
                seen.insert(day)
                let new = DayAssignment(
                    date: day,
                    preset: preset,
                    overrideAlarmHour: a.overrideAlarmHour,
                    overrideAlarmMinute: a.overrideAlarmMinute,
                    skipAlarm: a.skipAlarm,
                    note: a.note
                )
                context.insert(new)
                byDay[day] = new
            }
        }
    }

    private static func applyOverrides(
        _ overrides: [ShiftBundle.OverrideDTO],
        presets: [UUID: ShiftPreset],
        context: ModelContext,
        calendar: Calendar
    ) {
        var byDay: [Date: HolidayOverride] =
            ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        var seen = Set(byDay.keys)
        for o in overrides {
            guard let day = o.date.date(in: calendar) else { continue }
            let replacement = o.replacementPresetID.flatMap { presets[$0] }
            if let existing = byDay[day] {
                existing.kind = o.kind
                existing.label = o.label
                existing.skipAlarm = o.skipAlarm
                existing.replacementPreset = replacement
            } else if !seen.contains(day) {
                seen.insert(day)
                let new = HolidayOverride(
                    date: day,
                    kind: o.kind,
                    label: o.label,
                    skipAlarm: o.skipAlarm,
                    replacementPreset: replacement
                )
                context.insert(new)
                byDay[day] = new
            }
        }
    }
}
