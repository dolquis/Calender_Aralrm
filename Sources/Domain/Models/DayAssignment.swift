import Foundation
import SwiftData

public typealias DayAssignment = SchemaV4.DayAssignment

extension SchemaV4 {
    @Model
    public final class DayAssignment {
        @Attribute(.unique) public var id: UUID
        /// Normalized to local-timezone start-of-day.
        public var date: Date
        @Relationship public var preset: ShiftPreset?
        public var overrideAlarmHour: Int?
        public var overrideAlarmMinute: Int?
        public var skipAlarm: Bool
        public var note: String

        public init(
            id: UUID = UUID(),
            date: Date,
            preset: ShiftPreset? = nil,
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
}
