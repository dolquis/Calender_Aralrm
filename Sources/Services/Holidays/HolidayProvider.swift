import Foundation

public struct HolidayEntry: Codable, Sendable, Hashable {
    public let date: String
    public let name: String
}

public enum HolidayProvider {
    public static func loadJapaneseHolidays(in bundle: Bundle = .main) -> [HolidayEntry] {
        guard let url = bundle.url(forResource: "HolidaysJP", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return []
        }
        return (try? JSONDecoder().decode([HolidayEntry].self, from: data)) ?? []
    }

    /// Parses a Gregorian "YYYY-MM-DD" string as the start of day in the caller's time zone.
    /// The Y/M/D fields are always interpreted in the Gregorian calendar so devices with a
    /// non-Gregorian preferred calendar (e.g. Japanese) don't remap the numeric year.
    public static func parseLocalDay(_ raw: String, calendar: Calendar = .current) -> Date? {
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return gregorian.date(from: components).map { gregorian.startOfDay(for: $0) }
    }

    public static func entries(
        in range: ClosedRange<Date>, calendar: Calendar = .current, bundle: Bundle = .main
    ) -> [(Date, String)] {
        loadJapaneseHolidays(in: bundle).compactMap { entry in
            guard let date = parseLocalDay(entry.date, calendar: calendar) else { return nil }
            guard range.contains(date) else { return nil }
            return (date, entry.name)
        }
    }
}
