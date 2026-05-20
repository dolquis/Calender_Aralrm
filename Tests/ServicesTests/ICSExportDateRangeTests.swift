import XCTest
@testable import ShiftAlarm

final class ICSExportDateRangeTests: XCTestCase {
    private var tokyoTZ: TimeZone { TimeZone(identifier: "Asia/Tokyo")! }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tokyoTZ
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        dc.timeZone = tokyoTZ
        return calendar.date(from: dc)!
    }

    func testOneMonthRangeExcludesExclusiveEndDay() {
        let startDate = date(2026, 5, 19)
        let exportRange = ICSExportDateRange.make(
            today: startDate,
            months: 1,
            calendar: calendar
        )

        XCTAssertEqual(exportRange.range.lowerBound, startDate)
        XCTAssertEqual(exportRange.range.upperBound, date(2026, 6, 18))
        XCTAssertEqual(exportRange.dates.first, startDate)
        XCTAssertEqual(exportRange.dates.last, date(2026, 6, 18))
        XCTAssertEqual(exportRange.dates.count, 31)
        XCTAssertFalse(exportRange.dates.contains(date(2026, 6, 19)))
    }
}
