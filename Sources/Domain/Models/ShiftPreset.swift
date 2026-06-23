import Foundation
import SwiftData

public typealias ShiftPreset = SchemaV4.ShiftPreset

extension SchemaV4 {
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
        /// Target sleep duration in seconds (default 8 hours). Used to back-calculate bedtime from wake time.
        public var targetSleepDuration: Double = 8 * 3600
        /// Minutes before computed bedtime to fire the AlarmKit bedtime reminder. 0 = disabled.
        public var bedtimeLeadMinutes: Int = 30
        /// Optional vacation-crossing policy override. nil means the rotation pattern policy applies.
        public var crossVacationPolicyRaw: Int?

        @Relationship(deleteRule: .nullify, inverse: \DayAssignment.preset)
        public var assignments: [DayAssignment] = []

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
            bedtimeLeadMinutes: Int = 30,
            crossVacationPolicy: CrossVacationPolicy? = nil
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
            self.crossVacationPolicyRaw = crossVacationPolicy?.rawValue
        }

        public var defaultAlarmTime: DateComponents? {
            guard let h = defaultAlarmHour, let m = defaultAlarmMinute else { return nil }
            var dc = DateComponents()
            dc.hour = h
            dc.minute = m
            return dc
        }

        public var crossVacationPolicy: CrossVacationPolicy? {
            get { crossVacationPolicyRaw.flatMap(CrossVacationPolicy.init(rawValue:)) }
            set { crossVacationPolicyRaw = newValue?.rawValue }
        }
    }
}
