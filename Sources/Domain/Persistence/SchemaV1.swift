import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV1.ShiftPreset.self,
            SchemaV1.ShiftAlarm.self,
            SchemaV1.DayAssignment.self,
            SchemaV1.RotationPattern.self,
            SchemaV1.HolidayOverride.self,
            SchemaV1.AppSettings.self,
        ]
    }
}

extension SchemaV1 {
    @Model
    public final class ShiftPreset {
        @Attribute(.unique) public var id: UUID
        public var name: String
        public var colorHex: String
        public var defaultAlarmHour: Int?
        public var defaultAlarmMinute: Int?
        public var soundID: String
        public var note: String
        public var createdAt: Date
        public var targetSleepDuration: Double = 8 * 3600
        public var bedtimeLeadMinutes: Int = 30

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.DayAssignment.preset)
        public var assignments: [SchemaV1.DayAssignment] = []

        public init(
            id: UUID = UUID(),
            name: String,
            colorHex: String = "#1E88E5",
            defaultAlarmHour: Int? = nil,
            defaultAlarmMinute: Int? = nil,
            soundID: String = AlarmSound.systemDefault.id,
            note: String = "",
            createdAt: Date = .now,
            targetSleepDuration: Double = 8 * 3600,
            bedtimeLeadMinutes: Int = 30
        ) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.defaultAlarmHour = defaultAlarmHour
            self.defaultAlarmMinute = defaultAlarmMinute
            self.soundID = soundID
            self.note = note
            self.createdAt = createdAt
            self.targetSleepDuration = targetSleepDuration
            self.bedtimeLeadMinutes = bedtimeLeadMinutes
        }
    }

    @Model
    public final class ShiftAlarm {
        @Attribute(.unique) public var id: UUID
        /// Absolute fire date in the user's calendar.
        public var fireDate: Date
        public var label: String
        public var soundID: String
        public var isEnabled: Bool
        /// AlarmKit registration identifier. nil when not yet scheduled.
        public var alarmKitID: UUID?
        /// True for bedtime reminder alarms; false (default) for wake alarms.
        public var isBedtimeReminder: Bool = false
        @Relationship public var assignment: SchemaV1.DayAssignment?

        public init(
            id: UUID = UUID(),
            fireDate: Date,
            label: String,
            soundID: String = AlarmSound.systemDefault.id,
            isEnabled: Bool = true,
            alarmKitID: UUID? = nil,
            isBedtimeReminder: Bool = false,
            assignment: SchemaV1.DayAssignment? = nil
        ) {
            self.id = id
            self.fireDate = fireDate
            self.label = label
            self.soundID = soundID
            self.isEnabled = isEnabled
            self.alarmKitID = alarmKitID
            self.isBedtimeReminder = isBedtimeReminder
            self.assignment = assignment
        }
    }

    @Model
    public final class DayAssignment {
        @Attribute(.unique) public var id: UUID
        public var date: Date
        @Relationship public var preset: SchemaV1.ShiftPreset?
        public var overrideAlarmHour: Int?
        public var overrideAlarmMinute: Int?
        public var skipAlarm: Bool
        public var note: String

        public init(
            id: UUID = UUID(),
            date: Date,
            preset: SchemaV1.ShiftPreset? = nil,
            overrideAlarmHour: Int? = nil,
            overrideAlarmMinute: Int? = nil,
            skipAlarm: Bool = false,
            note: String = ""
        ) {
            self.id = id
            self.date = date
            self.preset = preset
            self.overrideAlarmHour = overrideAlarmHour
            self.overrideAlarmMinute = overrideAlarmMinute
            self.skipAlarm = skipAlarm
            self.note = note
        }
    }

    @Model
    public final class RotationPattern {
        @Attribute(.unique) public var id: UUID
        public var name: String
        public var anchorDate: Date
        public var cycleLength: Int
        public var slotsData: Data
        public var startDate: Date?
        public var endDate: Date?
        public var priority: Int
        public var isActive: Bool

        public init(
            id: UUID = UUID(),
            name: String,
            anchorDate: Date,
            cycleLength: Int,
            slots: [UUID?],
            startDate: Date? = nil,
            endDate: Date? = nil,
            priority: Int = 0,
            isActive: Bool = true
        ) {
            self.id = id
            self.name = name
            self.anchorDate = anchorDate
            self.cycleLength = cycleLength
            self.slotsData =
                (try? JSONEncoder().encode(slots.map { $0?.uuidString })) ?? Data("[]".utf8)
            self.startDate = startDate
            self.endDate = endDate
            self.priority = priority
            self.isActive = isActive
        }
    }

    @Model
    public final class HolidayOverride {
        public enum Kind: Int, Codable, Sendable {
            case publicHoliday
            case paidLeave
            case custom
        }

        @Attribute(.unique) public var id: UUID
        public var date: Date
        public var kindRaw: Int
        public var label: String
        public var skipAlarm: Bool
        @Relationship public var replacementPreset: SchemaV1.ShiftPreset?

        public init(
            id: UUID = UUID(),
            date: Date,
            kind: Kind,
            label: String,
            skipAlarm: Bool = true,
            replacementPreset: SchemaV1.ShiftPreset? = nil
        ) {
            self.id = id
            self.date = date
            self.kindRaw = kind.rawValue
            self.label = label
            self.skipAlarm = skipAlarm
            self.replacementPreset = replacementPreset
        }
    }

    @Model
    public final class AppSettings {
        @Attribute(.unique) public var id: UUID
        public var defaultSoundID: String
        public var lookaheadDays: Int
        public var liveActivityLeadHours: Int
        public var preferredLanguageRaw: String?
        public var hasOnboarded: Bool
        public var patternSuggestionSnoozedUntil: Date?
        public var patternSuggestionSnoozedFingerprint: String?
        public var patternDriftThreshold: Double?

        public init(
            id: UUID = UUID(),
            defaultSoundID: String = AlarmSound.systemDefault.id,
            lookaheadDays: Int = 30,
            liveActivityLeadHours: Int = 8,
            preferredLanguageRaw: String? = nil,
            hasOnboarded: Bool = false,
            patternSuggestionSnoozedUntil: Date? = nil,
            patternSuggestionSnoozedFingerprint: String? = nil,
            patternDriftThreshold: Double = 0.15
        ) {
            self.id = id
            self.defaultSoundID = defaultSoundID
            self.lookaheadDays = lookaheadDays
            self.liveActivityLeadHours = liveActivityLeadHours
            self.preferredLanguageRaw = preferredLanguageRaw
            self.hasOnboarded = hasOnboarded
            self.patternSuggestionSnoozedUntil = patternSuggestionSnoozedUntil
            self.patternSuggestionSnoozedFingerprint = patternSuggestionSnoozedFingerprint
            self.patternDriftThreshold = patternDriftThreshold
        }
    }
}
