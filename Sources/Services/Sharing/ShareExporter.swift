import Foundation
import SwiftData

@MainActor
public enum ShareExporter {
    typealias CalendarDayFactory = (Date, Calendar) -> CalendarDay?

    public static func snapshot(
        from container: ModelContainer, calendar: Calendar = .current
    ) throws -> ShiftBundle {
        try snapshot(
            from: container,
            calendar: calendar,
            makeCalendarDay: { date, calendar in
                CalendarDay(date: date, calendar: calendar)
            }
        )
    }

    static func snapshot(
        from container: ModelContainer,
        calendar: Calendar,
        makeCalendarDay: CalendarDayFactory
    ) throws -> ShiftBundle {
        let context = ModelContext(container)
        let presets: [ShiftPreset] = (try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        let patterns: [RotationPattern] =
            (try? context.fetch(FetchDescriptor<RotationPattern>())) ?? []
        let assignments: [DayAssignment] =
            (try? context.fetch(FetchDescriptor<DayAssignment>())) ?? []
        let overrides: [HolidayOverride] =
            (try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? []
        // The app-wide default is device-local and is not exported. We use it here only to
        // resolve `inherit` rows to a concrete value so the recipient inherits the sender's
        // effective intent rather than re-resolving against their own default.
        let holidayDefault =
            (try? context.fetch(FetchDescriptor<AppSettings>()))?.first?
            .effectiveHolidayAlarmDefault ?? .silence

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
                calendar: calendar,
                makeCalendarDay: makeCalendarDay
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
                        calendar: calendar,
                        makeCalendarDay: makeCalendarDay
                    )
                },
                endDate: try r.endDate.map {
                    try calendarDay(
                        from: $0,
                        entity: "RotationPattern",
                        field: "endDate",
                        calendar: calendar,
                        makeCalendarDay: makeCalendarDay
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
                calendar: calendar,
                makeCalendarDay: makeCalendarDay
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
                calendar: calendar,
                makeCalendarDay: makeCalendarDay
            )
            // Resolve `inherit` to a concrete value for the bundle; `ring`/`silence` pass
            // through. `skipAlarm` mirrors the effective value for legacy readers.
            let effective = o.effectiveBehavior(globalDefault: holidayDefault)
            return ShiftBundle.OverrideDTO(
                date: day,
                kind: o.kind,
                label: o.label,
                skipAlarm: effective == .silence,
                replacementPresetID: o.replacementPreset?.id,
                alarmBehavior: effective
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
        calendar: Calendar,
        makeCalendarDay: CalendarDayFactory
    ) throws -> CalendarDay {
        guard let day = makeCalendarDay(date, calendar) else {
            throw ShareExportError.invalidCalendarDay(entity: entity, field: field)
        }
        return day
    }
}

public enum ShareExportError: LocalizedError, Equatable {
    case invalidCalendarDay(entity: String, field: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCalendarDay:
            return String(localized: "export.error.invalid_calendar_day")
        }
    }
}
