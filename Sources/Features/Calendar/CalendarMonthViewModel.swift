import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class CalendarMonthViewModel {
    public private(set) var anchorMonth: Date
    public let calendar: Calendar

    public init(anchorMonth: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        self.anchorMonth = calendar.startOfMonth(for: anchorMonth)
    }

    public func step(by months: Int) {
        if let new = calendar.date(byAdding: .month, value: months, to: anchorMonth) {
            anchorMonth = calendar.startOfMonth(for: new)
        }
    }

    public func gridDates() -> [Date] {
        let firstWeekday = calendar.component(.weekday, from: anchorMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let startOfGrid = calendar.date(byAdding: .day, value: -leadingBlanks, to: anchorMonth)!
        let days = (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfGrid) }
        return days
    }

    public func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: anchorMonth, toGranularity: .month)
    }

    public func monthTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: anchorMonth)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
