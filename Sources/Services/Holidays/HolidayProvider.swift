import Foundation

public struct HolidayEntry: Codable, Sendable, Hashable {
    public let date: String
    public let name: String
}

public enum HolidayProvider {
    public static func loadJapaneseHolidays(in bundle: Bundle = .main) -> [HolidayEntry] {
        guard let url = bundle.url(forResource: "HolidaysJP", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([HolidayEntry].self, from: data)) ?? []
    }

    /// Parses a "YYYY-MM-DD" string as the start of day in the supplied calendar's time zone, so
    /// users in offsets behind GMT don't see the date shift to the previous day.
    public static func parseLocalDay(_ raw: String, calendar: Calendar = .current) -> Date? {
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    public static func entries(in range: ClosedRange<Date>, calendar: Calendar = .current, bundle: Bundle = .main) -> [(Date, String)] {
        loadJapaneseHolidays(in: bundle).compactMap { entry in
            guard let date = parseLocalDay(entry.date, calendar: calendar) else { return nil }
            guard range.contains(date) else { return nil }
            return (date, entry.name)
        }
    }
}
