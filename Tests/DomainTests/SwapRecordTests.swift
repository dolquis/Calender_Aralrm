import Foundation
import Testing

@testable import ShiftAlarm

struct SwapRecordTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    @Test
    func testNormalizesDateToStartOfDay() throws {
        let date = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 6,
                    day: 28,
                    hour: 22,
                    minute: 15
                )))

        let record = SwapRecord(
            date: date,
            kind: .covering,
            counterpartyLabel: "A",
            note: "night cover",
            calendar: calendar
        )

        #expect(record.date == calendar.startOfDay(for: date))
        #expect(record.kind == .covering)
        #expect(record.counterpartyLabel == "A")
        #expect(record.note == "night cover")
    }

    @Test
    func testInvalidKindFallsBackToExchange() {
        let record = SwapRecord(
            date: Date(timeIntervalSince1970: 0),
            kind: .covered,
            counterpartyLabel: "A",
            calendar: calendar
        )

        record.kindRaw = 999

        #expect(record.kind == .exchange)
    }

    @Test
    func testManuallyEditableKindsExcludeExchange() {
        #expect(SwapRecord.Kind.manuallyEditableCases == [.covered, .covering])
        #expect(SwapRecord.Kind.allCases.contains(.exchange))
    }
}
