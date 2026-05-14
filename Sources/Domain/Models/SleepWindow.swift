import Foundation

/// A computed sleep window derived from a shift's wake alarm and target sleep duration.
public struct SleepWindow: Sendable, Equatable {
    /// The date (start of day) this window belongs to.
    public let date: Date
    /// When the alarm fires (wake time).
    public let wakeTime: Date
    /// Computed bedtime = wakeTime − targetSleepDuration.
    public let bedtime: Date
    /// When to fire the bedtime reminder alarm (bedtime − bedtimeLeadMinutes). nil if lead is 0.
    public let reminderFireDate: Date?
    public let presetID: UUID?
    public let presetName: String

    public init(
        date: Date,
        wakeTime: Date,
        bedtime: Date,
        reminderFireDate: Date?,
        presetID: UUID?,
        presetName: String
    ) {
        self.date = date
        self.wakeTime = wakeTime
        self.bedtime = bedtime
        self.reminderFireDate = reminderFireDate
        self.presetID = presetID
        self.presetName = presetName
    }
}
