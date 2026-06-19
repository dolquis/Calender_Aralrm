import Foundation
import SwiftData

extension SchemaV2 {
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

        @Relationship(deleteRule: .nullify, inverse: \SchemaV2.DayAssignment.preset)
        public var assignments: [SchemaV2.DayAssignment] = []

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

        public var defaultAlarmTime: DateComponents? {
            guard let h = defaultAlarmHour, let m = defaultAlarmMinute else { return nil }
            var dc = DateComponents()
            dc.hour = h
            dc.minute = m
            return dc
        }
    }

    @Model
    public final class ShiftAlarm {
        public static let emptyPendingCancelData = Data("[]".utf8)

        @Attribute(.unique) public var id: UUID
        public var fireDate: Date
        public var label: String
        public var soundID: String
        public var isEnabled: Bool
        @Attribute(originalName: "alarmKitID") public var currentAlarmKitID: UUID?
        public var pendingCancelData: Data = emptyPendingCancelData
        public var isBedtimeReminder: Bool = false
        @Relationship public var assignment: SchemaV2.DayAssignment?

        public init(
            id: UUID = UUID(),
            fireDate: Date,
            label: String,
            soundID: String = AlarmSound.systemDefault.id,
            isEnabled: Bool = true,
            alarmKitID: UUID? = nil,
            currentAlarmKitID: UUID? = nil,
            pendingCancelIDs: [UUID] = [],
            isBedtimeReminder: Bool = false,
            assignment: SchemaV2.DayAssignment? = nil
        ) {
            self.id = id
            self.fireDate = fireDate
            self.label = label
            self.soundID = soundID
            self.isEnabled = isEnabled
            self.currentAlarmKitID = currentAlarmKitID ?? alarmKitID
            self.pendingCancelData = Self.encodePendingCancelIDs(pendingCancelIDs)
            self.isBedtimeReminder = isBedtimeReminder
            self.assignment = assignment
        }

        public var alarmKitID: UUID? {
            get { currentAlarmKitID }
            set { currentAlarmKitID = newValue }
        }

        public var pendingCancelIDs: [UUID] {
            get {
                (try? JSONDecoder().decode([UUID].self, from: pendingCancelData)) ?? []
            }
            set {
                pendingCancelData = Self.encodePendingCancelIDs(newValue)
            }
        }

        public func appendPendingCancelID(_ id: UUID) {
            var ids = pendingCancelIDs
            guard !ids.contains(id) else { return }
            ids.append(id)
            pendingCancelIDs = ids
        }

        public func removePendingCancelID(_ id: UUID) {
            pendingCancelIDs = pendingCancelIDs.filter { $0 != id }
        }

        private static func encodePendingCancelIDs(_ ids: [UUID]) -> Data {
            (try? JSONEncoder().encode(ids)) ?? emptyPendingCancelData
        }
    }

    @Model
    public final class DayAssignment {
        @Attribute(.unique) public var id: UUID
        public var date: Date
        @Relationship public var preset: SchemaV2.ShiftPreset?
        public var overrideAlarmHour: Int?
        public var overrideAlarmMinute: Int?
        public var skipAlarm: Bool
        public var note: String

        public init(
            id: UUID = UUID(),
            date: Date,
            preset: SchemaV2.ShiftPreset? = nil,
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

        public var overrideAlarmTime: DateComponents? {
            guard let h = overrideAlarmHour, let m = overrideAlarmMinute else { return nil }
            var dc = DateComponents()
            dc.hour = h
            dc.minute = m
            return dc
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

        public var slots: [UUID?] {
            get {
                guard let strings = try? JSONDecoder().decode([String?].self, from: slotsData)
                else {
                    return []
                }
                return strings.map { $0.flatMap(UUID.init(uuidString:)) }
            }
            set {
                slotsData =
                    (try? JSONEncoder().encode(newValue.map { $0?.uuidString }))
                    ?? Data("[]".utf8)
            }
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
        @Relationship public var replacementPreset: SchemaV2.ShiftPreset?

        public init(
            id: UUID = UUID(),
            date: Date,
            kind: Kind,
            label: String,
            skipAlarm: Bool = true,
            replacementPreset: SchemaV2.ShiftPreset? = nil
        ) {
            self.id = id
            self.date = date
            self.kindRaw = kind.rawValue
            self.label = label
            self.skipAlarm = skipAlarm
            self.replacementPreset = replacementPreset
        }

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .custom }
            set { kindRaw = newValue.rawValue }
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
