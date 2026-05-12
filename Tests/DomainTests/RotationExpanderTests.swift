import XCTest
@testable import ShiftAlarm

final class RotationExpanderTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d
        return calendar.date(from: dc)!
    }

    func testFourOnTwoOffCycle() {
        let dayShift = UUID()
        let nightShift = UUID()
        let pattern = RotationPatternSnapshot(
            id: UUID(),
            name: "4-on/2-off",
            anchorDate: date(2026, 1, 1),
            cycleLength: 6,
            slots: [dayShift, dayShift, nightShift, nightShift, nil, nil],
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: true
        )

        XCTAssertEqual(RotationExpander.presetID(for: date(2026, 1, 1), pattern: pattern, calendar: calendar), dayShift)
        XCTAssertEqual(RotationExpander.presetID(for: date(2026, 1, 3), pattern: pattern, calendar: calendar), nightShift)
        XCTAssertNil(RotationExpander.presetID(for: date(2026, 1, 5), pattern: pattern, calendar: calendar) ?? nil)
        // Wrap around the cycle
        XCTAssertEqual(RotationExpander.presetID(for: date(2026, 1, 7), pattern: pattern, calendar: calendar), dayShift)
    }

    func testNegativeOffsetIsHandled() {
        let preset = UUID()
        let pattern = RotationPatternSnapshot(
            id: UUID(),
            name: "single",
            anchorDate: date(2026, 6, 1),
            cycleLength: 3,
            slots: [preset, nil, nil],
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: true
        )
        // 2026-05-30 is anchor - 2 days, index = (-2 % 3 + 3) % 3 = 1 -> nil
        XCTAssertNil(RotationExpander.presetID(for: date(2026, 5, 30), pattern: pattern, calendar: calendar) ?? nil)
        // 2026-05-29 = anchor - 3, index 0 -> preset
        XCTAssertEqual(RotationExpander.presetID(for: date(2026, 5, 29), pattern: pattern, calendar: calendar), preset)
    }

    func testEmptyPatternReturnsNil() {
        let pattern = RotationPatternSnapshot(
            id: UUID(),
            name: "empty",
            anchorDate: date(2026, 1, 1),
            cycleLength: 0,
            slots: [],
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: true
        )
        XCTAssertNil(RotationExpander.presetID(for: date(2026, 1, 1), pattern: pattern, calendar: calendar) ?? nil)
    }
}
