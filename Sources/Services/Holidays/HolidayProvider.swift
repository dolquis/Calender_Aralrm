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

    public static func entries(in range: ClosedRange<Date>, bundle: Bundle = .main) -> [(Date, String)] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return loadJapaneseHolidays(in: bundle).compactMap { entry in
            guard let date = formatter.date(from: entry.date) else { return nil }
            guard range.contains(date) else { return nil }
            return (date, entry.name)
        }
    }
}
