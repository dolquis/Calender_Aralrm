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

    public var hasChanges: Bool {
        addedPresets + updatedPresets +
        addedPatterns + updatedPatterns +
        addedAssignments + updatedAssignments +
        addedOverrides + updatedOverrides > 0
    }
}

@MainActor
public enum ShareImporter {
    public static func preview(bundle: ShiftBundle, container: ModelContainer, calendar: Calendar = .current) -> ImportPreview {
        let context = ModelContext(container)
        let existingPresets: [UUID: ShiftPreset] = ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let existingPatterns: [UUID: RotationPattern] = ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let existingAssignments: [Date: DayAssignment] = ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        let existingOverrides: [Date: HolidayOverride] = ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }

        var addedPresets = 0, updatedPresets = 0
        for p in bundle.presets {
            if existingPresets[p.id] == nil { addedPresets += 1 } else { updatedPresets += 1 }
        }
        var addedPatterns = 0, updatedPatterns = 0
        for r in bundle.patterns {
            if existingPatterns[r.id] == nil { addedPatterns += 1 } else { updatedPatterns += 1 }
        }
        var addedAssignments = 0, updatedAssignments = 0
        for a in bundle.assignments {
            guard let day = a.date.date(in: calendar) else { continue }
            if existingAssignments[day] == nil { addedAssignments += 1 } else { updatedAssignments += 1 }
        }
        var addedOverrides = 0, updatedOverrides = 0
        for o in bundle.overrides {
            guard let day = o.date.date(in: calendar) else { continue }
            if existingOverrides[day] == nil { addedOverrides += 1 } else { updatedOverrides += 1 }
        }
        return ImportPreview(
            addedPresets: addedPresets,
            updatedPresets: updatedPresets,
            addedPatterns: addedPatterns,
            updatedPatterns: updatedPatterns,
            addedAssignments: addedAssignments,
            updatedAssignments: updatedAssignments,
            addedOverrides: addedOverrides,
            updatedOverrides: updatedOverrides
        )
    }

    public static func apply(bundle: ShiftBundle, container: ModelContainer, calendar: Calendar = .current) throws {
        let context = ModelContext(container)

        var existingPresets: [UUID: ShiftPreset] = ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }

        for p in bundle.presets {
            if let existing = existingPresets[p.id] {
                existing.name = p.name
                existing.colorHex = p.colorHex
                existing.defaultAlarmHour = p.defaultAlarmHour
                existing.defaultAlarmMinute = p.defaultAlarmMinute
                existing.soundID = p.soundID
                existing.note = p.note
            } else {
                let new = ShiftPreset(
                    id: p.id,
                    name: p.name,
                    colorHex: p.colorHex,
                    defaultAlarmHour: p.defaultAlarmHour,
                    defaultAlarmMinute: p.defaultAlarmMinute,
                    soundID: p.soundID,
                    note: p.note
                )
                context.insert(new)
                existingPresets[p.id] = new
            }
        }

        let presetsByID = existingPresets

        var existingPatterns: [UUID: RotationPattern] = ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        for r in bundle.patterns {
            guard let anchor = r.anchorDate.date(in: calendar) else { continue }
            let start = r.startDate?.date(in: calendar)
            let end = r.endDate?.date(in: calendar)
            if let existing = existingPatterns[r.id] {
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
                existingPatterns[r.id] = new
            }
        }

        var existingAssignments: [Date: DayAssignment] = ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        for a in bundle.assignments {
            guard let day = a.date.date(in: calendar) else { continue }
            let preset = a.presetID.flatMap { presetsByID[$0] }
            if let existing = existingAssignments[day] {
                existing.preset = preset
                existing.overrideAlarmHour = a.overrideAlarmHour
                existing.overrideAlarmMinute = a.overrideAlarmMinute
                existing.skipAlarm = a.skipAlarm
                existing.note = a.note
            } else {
                let new = DayAssignment(
                    date: day,
                    preset: preset,
                    overrideAlarmHour: a.overrideAlarmHour,
                    overrideAlarmMinute: a.overrideAlarmMinute,
                    skipAlarm: a.skipAlarm,
                    note: a.note
                )
                context.insert(new)
                existingAssignments[day] = new
            }
        }

        var existingOverrides: [Date: HolidayOverride] = ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        for o in bundle.overrides {
            guard let day = o.date.date(in: calendar) else { continue }
            let replacement = o.replacementPresetID.flatMap { presetsByID[$0] }
            if let existing = existingOverrides[day] {
                existing.kind = o.kind
                existing.label = o.label
                existing.skipAlarm = o.skipAlarm
                existing.replacementPreset = replacement
            } else {
                let new = HolidayOverride(
                    date: day,
                    kind: o.kind,
                    label: o.label,
                    skipAlarm: o.skipAlarm,
                    replacementPreset: replacement
                )
                context.insert(new)
                existingOverrides[day] = new
            }
        }

        try context.save()
    }
}
