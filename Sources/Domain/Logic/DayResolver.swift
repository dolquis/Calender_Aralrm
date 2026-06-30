import Foundation

public enum ResolvedDay: Equatable {
    case manual(presetID: UUID?, alarmTime: DateComponents?, skip: Bool, note: String)
    case holiday(label: String, replacementPresetID: UUID?, alarmTime: DateComponents?, skip: Bool)
    case rotation(presetID: UUID, alarmTime: DateComponents?)
    case none

    public var skipsAlarm: Bool {
        switch self {
        case .manual(_, _, let skip, _): return skip
        case .holiday(_, _, _, let skip): return skip
        case .rotation: return false
        case .none: return true
        }
    }

    public var fireTime: DateComponents? {
        switch self {
        case .manual(_, let t, let skip, _): return skip ? nil : t
        case .holiday(_, _, let t, let skip): return skip ? nil : t
        case .rotation(_, let t): return t
        case .none: return nil
        }
    }

    public var presetID: UUID? {
        switch self {
        case .manual(let id, _, _, _): return id
        case .holiday(_, let id, _, _): return id
        case .rotation(let id, _): return id
        case .none: return nil
        }
    }
}

public struct DayResolverInput {
    public let manualAssignments: [Date: DayAssignmentSnapshot]
    public let holidays: [Date: HolidayOverrideSnapshot]
    public let rotations: [RotationPatternSnapshot]
    public let presets: [UUID: ShiftPresetSnapshot]
    public let vacations: [VacationPeriodSnapshot]
    public let swapRecords: [Date: [SwapRecordSnapshot]]
    public let calendar: Calendar

    public init(
        manualAssignments: [Date: DayAssignmentSnapshot],
        holidays: [Date: HolidayOverrideSnapshot],
        rotations: [RotationPatternSnapshot],
        presets: [UUID: ShiftPresetSnapshot],
        vacations: [VacationPeriodSnapshot] = [],
        swapRecords: [Date: [SwapRecordSnapshot]] = [:],
        calendar: Calendar = .current
    ) {
        self.manualAssignments = manualAssignments
        self.holidays = holidays
        self.rotations = rotations
        self.presets = presets
        self.calendar = calendar
        self.vacations = VacationAwareRotation.normalizedVacations(vacations, calendar: calendar)
        self.swapRecords = swapRecords.reduce(into: [:]) { acc, element in
            acc[calendar.startOfDay(for: element.key)] = element.value
        }
    }
}

public struct DayAssignmentSnapshot: Sendable, Equatable {
    public let presetID: UUID?
    public let overrideTime: DateComponents?
    public let skipAlarm: Bool
    public let note: String

    public init(presetID: UUID?, overrideTime: DateComponents?, skipAlarm: Bool, note: String) {
        self.presetID = presetID
        self.overrideTime = overrideTime
        self.skipAlarm = skipAlarm
        self.note = note
    }
}

public struct HolidayOverrideSnapshot: Sendable, Equatable {
    public let label: String
    public let skipAlarm: Bool
    public let replacementPresetID: UUID?

    public init(label: String, skipAlarm: Bool, replacementPresetID: UUID?) {
        self.label = label
        self.skipAlarm = skipAlarm
        self.replacementPresetID = replacementPresetID
    }
}

public struct ShiftPresetSnapshot: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let colorHex: String
    public let alarmTime: DateComponents?
    public let soundID: String
    public let targetSleepDuration: Double
    public let bedtimeLeadMinutes: Int
    public let crossVacationPolicy: CrossVacationPolicy?

    public init(
        id: UUID,
        name: String,
        colorHex: String,
        alarmTime: DateComponents?,
        soundID: String,
        targetSleepDuration: Double = 8 * 3600,
        bedtimeLeadMinutes: Int = 30,
        crossVacationPolicy: CrossVacationPolicy? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.alarmTime = alarmTime
        self.soundID = soundID
        self.targetSleepDuration = targetSleepDuration
        self.bedtimeLeadMinutes = bedtimeLeadMinutes
        self.crossVacationPolicy = crossVacationPolicy
    }
}

public struct RotationPatternSnapshot: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let anchorDate: Date
    public let cycleLength: Int
    public let slots: [UUID?]
    public let startDate: Date?
    public let endDate: Date?
    public let priority: Int
    public let isActive: Bool
    public let crossVacationPolicy: CrossVacationPolicy
    public let dayStartSlotIndex: Int?

    public init(
        id: UUID,
        name: String,
        anchorDate: Date,
        cycleLength: Int,
        slots: [UUID?],
        startDate: Date?,
        endDate: Date?,
        priority: Int,
        isActive: Bool,
        crossVacationPolicy: CrossVacationPolicy = .invert,
        dayStartSlotIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.anchorDate = anchorDate
        self.cycleLength = cycleLength
        self.slots = slots
        self.startDate = startDate
        self.endDate = endDate
        self.priority = priority
        self.isActive = isActive
        self.crossVacationPolicy = crossVacationPolicy
        self.dayStartSlotIndex = dayStartSlotIndex
    }
}

public struct VacationPeriodSnapshot: Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let label: String

    public init(startDate: Date, endDate: Date, label: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.label = label
    }
}

public struct SwapRecordSnapshot: Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let kind: SwapRecord.Kind
    public let counterpartyLabel: String
    public let note: String
    public let createdAt: Date

    public init(
        id: UUID,
        date: Date,
        kind: SwapRecord.Kind,
        counterpartyLabel: String,
        note: String,
        createdAt: Date
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.counterpartyLabel = counterpartyLabel
        self.note = note
        self.createdAt = createdAt
    }
}

public enum DayResolver {
    public static func resolve(date: Date, input: DayResolverInput) -> ResolvedDay {
        let day = input.calendar.startOfDay(for: date)

        if let manual = input.manualAssignments[day] {
            let preset = manual.presetID.flatMap { input.presets[$0] }
            let time = manual.overrideTime ?? preset?.alarmTime
            return .manual(
                presetID: manual.presetID,
                alarmTime: time,
                skip: manual.skipAlarm,
                note: manual.note
            )
        }

        if let holiday = input.holidays[day] {
            if holiday.skipAlarm {
                return .holiday(
                    label: holiday.label, replacementPresetID: nil, alarmTime: nil, skip: true)
            }
            if let replacement = holiday.replacementPresetID.flatMap({ input.presets[$0] }) {
                return .holiday(
                    label: holiday.label,
                    replacementPresetID: holiday.replacementPresetID,
                    alarmTime: replacement.alarmTime,
                    skip: false
                )
            }
            // skipAlarm == false with no replacement preset: fall through to rotation resolution
            // so the normal scheduled alarm still fires on this holiday.
        }

        let candidates = input.rotations
            .filter { $0.isActive }
            .filter { Self.applies($0, to: day, calendar: input.calendar) }
            .sorted { $0.priority > $1.priority }

        for rotation in candidates {
            // Skip degenerate patterns (empty cycle, mismatched slot count) so they don't
            // block lower-priority rotations from being considered.
            guard rotation.cycleLength > 0,
                rotation.slots.count == rotation.cycleLength
            else { continue }
            // A valid rotation slot decides behavior for the day:
            // - presetID resolves to a loaded preset => schedule it.
            // - presetID is stale (preset deleted) => fall through to lower priority.
            // - nil slot => explicit rest day, do not fall through.
            if let presetID = VacationAwareRotation.presetID(
                for: day,
                pattern: rotation,
                normalizedVacations: input.vacations,
                presets: input.presets,
                calendar: input.calendar)
            {
                if let preset = input.presets[presetID] {
                    return .rotation(presetID: presetID, alarmTime: preset.alarmTime)
                }
                // If the referenced preset no longer exists, keep looking at lower-priority
                // rotations instead of treating it as an explicit rest day.
                continue
            }
            return .none
        }

        return .none
    }

    private static func applies(
        _ pattern: RotationPatternSnapshot, to day: Date, calendar: Calendar
    ) -> Bool {
        if let start = pattern.startDate, day < calendar.startOfDay(for: start) { return false }
        if let end = pattern.endDate, day > calendar.startOfDay(for: end) { return false }
        return true
    }
}
