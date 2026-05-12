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
    public static func preview(bundle: ShiftBundle, container: ModelContainer) -> ImportPreview {
        let context = ModelContext(container)
        let calendar = Calendar.current
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
            if existingAssignments[calendar.startOfDay(for: a.date)] == nil { addedAssignments += 1 } else { updatedAssignments += 1 }
        }
        var addedOverrides = 0, updatedOverrides = 0
        for o in bundle.overrides {
            if existingOverrides[calendar.startOfDay(for: o.date)] == nil { addedOverrides += 1 } else { updatedOverrides += 1 }
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

    public static func apply(bundle: ShiftBundle, container: ModelContainer) throws {
        let context = ModelContext(container)
        let calendar = Calendar.current

        let existingPresets: [UUID: ShiftPreset] = ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
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
            }
        }

        let presetsByID: [UUID: ShiftPreset] = ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }

        let existingPatterns: [UUID: RotationPattern] = ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        for r in bundle.patterns {
            if let existing = existingPatterns[r.id] {
                existing.name = r.name
                existing.anchorDate = r.anchorDate
                existing.cycleLength = r.cycleLength
                existing.slots = r.slots
                existing.startDate = r.startDate
                existing.endDate = r.endDate
                existing.priority = r.priority
                existing.isActive = r.isActive
            } else {
                let new = RotationPattern(
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
                context.insert(new)
            }
        }

        let existingAssignments: [Date: DayAssignment] = ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        for a in bundle.assignments {
            let day = calendar.startOfDay(for: a.date)
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
            }
        }

        let existingOverrides: [Date: HolidayOverride] = ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        for o in bundle.overrides {
            let day = calendar.startOfDay(for: o.date)
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
            }
        }

        try context.save()
    }
}
