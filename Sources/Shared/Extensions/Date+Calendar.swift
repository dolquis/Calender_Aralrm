import Foundation

public extension Date {
    func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    func adding(days: Int, in calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func combining(hour: Int, minute: Int, in calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    func isSameDay(as other: Date, in calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }
}

public extension Calendar {
    func daysBetween(_ a: Date, _ b: Date) -> Int {
        let dayA = startOfDay(for: a)
        let dayB = startOfDay(for: b)
        return dateComponents([.day], from: dayA, to: dayB).day ?? 0
    }
}
