import Foundation
import SwiftData

@MainActor
public enum ShareExporter {
    public static func snapshot(from container: ModelContainer, calendar: Calendar = .current) -> ShiftBundle {
        let context = ModelContext(container)
        let presets: [ShiftPreset] = (try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        let patterns: [RotationPattern] = (try? context.fetch(FetchDescriptor<RotationPattern>())) ?? []
        let assignments: [DayAssignment] = (try? context.fetch(FetchDescriptor<DayAssignment>())) ?? []
        let overrides: [HolidayOverride] = (try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? []

        let presetDTOs = presets.map { p in
            ShiftBundle.PresetDTO(
                id: p.id,
                name: p.name,
                colorHex: p.colorHex,
                defaultAlarmHour: p.defaultAlarmHour,
                defaultAlarmMinute: p.defaultAlarmMinute,
                soundID: p.soundID,
                note: p.note
            )
        }
        let rotationDTOs: [ShiftBundle.RotationDTO] = patterns.compactMap { r in
            guard let anchor = CalendarDay(date: r.anchorDate, calendar: calendar) else { return nil }
            return ShiftBundle.RotationDTO(
                id: r.id,
                name: r.name,
                anchorDate: anchor,
                cycleLength: r.cycleLength,
                slots: r.slots,
                startDate: r.startDate.flatMap { CalendarDay(date: $0, calendar: calendar) },
                endDate: r.endDate.flatMap { CalendarDay(date: $0, calendar: calendar) },
                priority: r.priority,
                isActive: r.isActive
            )
        }
        let assignmentDTOs: [ShiftBundle.AssignmentDTO] = assignments.compactMap { a in
            guard let day = CalendarDay(date: a.date, calendar: calendar) else { return nil }
            return ShiftBundle.AssignmentDTO(
                date: day,
                presetID: a.preset?.id,
                overrideAlarmHour: a.overrideAlarmHour,
                overrideAlarmMinute: a.overrideAlarmMinute,
                skipAlarm: a.skipAlarm,
                note: a.note
            )
        }
        let overrideDTOs: [ShiftBundle.OverrideDTO] = overrides.compactMap { o in
            guard let day = CalendarDay(date: o.date, calendar: calendar) else { return nil }
            return ShiftBundle.OverrideDTO(
                date: day,
                kind: o.kind,
                label: o.label,
                skipAlarm: o.skipAlarm,
                replacementPresetID: o.replacementPreset?.id
            )
        }
        return ShiftBundle(
            presets: presetDTOs,
            patterns: rotationDTOs,
            assignments: assignmentDTOs,
            overrides: overrideDTOs
        )
    }

    public static func writeTemporaryFile(bundle: ShiftBundle) throws -> URL {
        let data = try ShiftBundleCodec.encode(bundle)
        let directory = FileManager.default.temporaryDirectory
        let filename = "ShiftAlarm-\(ISO8601DateFormatter().string(from: .now)).shiftalarm"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
