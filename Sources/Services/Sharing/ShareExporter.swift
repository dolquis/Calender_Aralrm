import Foundation
import SwiftData

@MainActor
public enum ShareExporter {
    public static func snapshot(
        from container: ModelContainer, calendar: Calendar = .current
    ) throws -> ShiftBundle {
        let context = ModelContext(container)
        let presets: [ShiftPreset] = (try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        let patterns: [RotationPattern] =
            (try? context.fetch(FetchDescriptor<RotationPattern>())) ?? []
        let assignments: [DayAssignment] =
            (try? context.fetch(FetchDescriptor<DayAssignment>())) ?? []
        let overrides: [HolidayOverride] =
            (try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? []

        let presetDTOs = presets.map { p in
            ShiftBundle.PresetDTO(
                id: p.id,
                name: p.name,
                colorHex: p.colorHex,
                defaultAlarmHour: p.defaultAlarmHour,
                defaultAlarmMinute: p.defaultAlarmMinute,
                soundID: p.soundID,
                note: p.note,
                crossVacationPolicy: p.crossVacationPolicyRaw
            )
        }
        let rotationDTOs: [ShiftBundle.RotationDTO] = try patterns.map { r in
            let anchor = try calendarDay(
                from: r.anchorDate,
                entity: "RotationPattern",
                field: "anchorDate",
                calendar: calendar
            )
            return ShiftBundle.RotationDTO(
                id: r.id,
                name: r.name,
                anchorDate: anchor,
                cycleLength: r.cycleLength,
                slots: r.slots,
                startDate: try r.startDate.map {
                    try calendarDay(
                        from: $0,
                        entity: "RotationPattern",
                        field: "startDate",
                        calendar: calendar
                    )
                },
                endDate: try r.endDate.map {
                    try calendarDay(
                        from: $0,
                        entity: "RotationPattern",
                        field: "endDate",
                        calendar: calendar
                    )
                },
                priority: r.priority,
                isActive: r.isActive,
                crossVacationPolicy: r.crossVacationPolicy == .invert
                    ? nil : r.crossVacationPolicyRaw,
                dayStartSlotIndex: r.dayStartSlotIndex
            )
        }
        let assignmentDTOs: [ShiftBundle.AssignmentDTO] = try assignments.map { a in
            let day = try calendarDay(
                from: a.date,
                entity: "DayAssignment",
                field: "date",
                calendar: calendar
            )
            return ShiftBundle.AssignmentDTO(
                date: day,
                presetID: a.preset?.id,
                overrideAlarmHour: a.overrideAlarmHour,
                overrideAlarmMinute: a.overrideAlarmMinute,
                skipAlarm: a.skipAlarm,
                note: a.note
            )
        }
        let overrideDTOs: [ShiftBundle.OverrideDTO] = try overrides.map { o in
            let day = try calendarDay(
                from: o.date,
                entity: "HolidayOverride",
                field: "date",
                calendar: calendar
            )
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

    private static func calendarDay(
        from date: Date,
        entity: String,
        field: String,
        calendar: Calendar = .current
    ) throws -> CalendarDay {
        guard let day = CalendarDay(date: date, calendar: calendar) else {
            throw ShareExportError.invalidCalendarDay(entity: entity, field: field)
        }
        return day
    }
}

public enum ShareExportError: LocalizedError, Equatable {
    case invalidCalendarDay(entity: String, field: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCalendarDay(let entity, let field):
            return "Unable to export \(entity).\(field) as a calendar day."
        }
    }
}
