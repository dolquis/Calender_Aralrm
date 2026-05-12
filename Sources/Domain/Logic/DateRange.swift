import Foundation

public struct DayRange: Sequence, Sendable {
    public let start: Date
    public let end: Date
    public let calendar: Calendar

    public init(start: Date, end: Date, calendar: Calendar = .current) {
        self.start = calendar.startOfDay(for: start)
        self.end = calendar.startOfDay(for: end)
        self.calendar = calendar
    }

    public init(start: Date, dayCount: Int, calendar: Calendar = .current) {
        let s = calendar.startOfDay(for: start)
        let e = calendar.date(byAdding: .day, value: max(0, dayCount), to: s) ?? s
        self.init(start: s, end: e, calendar: calendar)
    }

    public func makeIterator() -> AnyIterator<Date> {
        var cursor = start
        let limit = end
        let cal = calendar
        return AnyIterator {
            guard cursor < limit else { return nil }
            let current = cursor
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? limit
            return current
        }
    }
}
