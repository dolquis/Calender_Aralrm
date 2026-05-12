import Foundation
import SwiftData

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
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.defaultAlarmHour = defaultAlarmHour
        self.defaultAlarmMinute = defaultAlarmMinute
        self.soundID = soundID
        self.note = note
        self.createdAt = createdAt
    }

    public var defaultAlarmTime: DateComponents? {
        guard let h = defaultAlarmHour, let m = defaultAlarmMinute else { return nil }
        var dc = DateComponents()
        dc.hour = h
        dc.minute = m
        return dc
    }
}
