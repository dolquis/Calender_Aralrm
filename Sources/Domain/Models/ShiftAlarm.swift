import Foundation
import SwiftData

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
    @Relationship public var assignment: DayAssignment?

    public init(
        id: UUID = UUID(),
        fireDate: Date,
        label: String,
        soundID: String = AlarmSound.systemDefault.id,
        isEnabled: Bool = true,
        alarmKitID: UUID? = nil,
        assignment: DayAssignment? = nil
    ) {
        self.id = id
        self.fireDate = fireDate
        self.label = label
        self.soundID = soundID
        self.isEnabled = isEnabled
        self.alarmKitID = alarmKitID
        self.assignment = assignment
    }
}
