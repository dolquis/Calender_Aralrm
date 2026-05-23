import Foundation

public enum RotationExpander {
    /// Returns the preset id that the rotation suggests for `day`, or nil for rest days.
    public static func presetID(
        for day: Date,
        pattern: RotationPatternSnapshot,
        calendar: Calendar = .current
    ) -> UUID? {
        guard pattern.cycleLength > 0, pattern.slots.count == pattern.cycleLength else {
            return nil
        }
        let anchor = calendar.startOfDay(for: pattern.anchorDate)
        let target = calendar.startOfDay(for: day)
        let dayDelta = calendar.dateComponents([.day], from: anchor, to: target).day ?? 0
        let cycle = pattern.cycleLength
        let index = ((dayDelta % cycle) + cycle) % cycle
        return pattern.slots[index]
    }

    /// Expands a rotation across a date range. The map keys are start-of-day dates.
    public static func expand(
        pattern: RotationPatternSnapshot,
        in range: DayRange
    ) -> [Date: UUID?] {
        guard pattern.cycleLength > 0, pattern.slots.count == pattern.cycleLength else {
            return [:]
        }
        var result: [Date: UUID?] = [:]
        for day in range {
            if let start = pattern.startDate, day < range.calendar.startOfDay(for: start) {
                continue
            }
            if let end = pattern.endDate, day > range.calendar.startOfDay(for: end) { continue }
            result[day] = presetID(for: day, pattern: pattern, calendar: range.calendar)
        }
        return result
    }
}
