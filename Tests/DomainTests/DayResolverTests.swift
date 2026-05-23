import XCTest

@testable import ShiftAlarm

final class DayResolverTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return calendar.date(from: dc)!
    }

    func testManualAssignmentTakesPrecedenceOverRotation() {
        let presetID = UUID()
        let preset = ShiftPresetSnapshot(
            id: presetID, name: "Day", colorHex: "#000",
            alarmTime: DateComponents(hour: 6, minute: 0),
            soundID: "system.default"
        )
        let manualID = UUID()
        let manualPreset = ShiftPresetSnapshot(
            id: manualID, name: "Manual", colorHex: "#fff",
            alarmTime: DateComponents(hour: 9, minute: 0),
            soundID: "system.default"
        )
        let day = date(2026, 5, 12)
        let manual = DayAssignmentSnapshot(
            presetID: manualID,
            overrideTime: nil,
            skipAlarm: false,
            note: ""
        )
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: date(2026, 5, 12),
            cycleLength: 1, slots: [presetID],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = DayResolverInput(
            manualAssignments: [day: manual],
            holidays: [:],
            rotations: [rotation],
            presets: [presetID: preset, manualID: manualPreset],
            calendar: calendar
        )
        let resolved = DayResolver.resolve(date: day, input: input)
        if case .manual(let id, let t, _, _) = resolved {
            XCTAssertEqual(id, manualID)
            XCTAssertEqual(t?.hour, 9)
        } else {
            XCTFail("Expected manual")
        }
    }

    func testHolidaySkipsAlarm() {
        let presetID = UUID()
        let preset = ShiftPresetSnapshot(
            id: presetID, name: "Day", colorHex: "#000",
            alarmTime: DateComponents(hour: 6, minute: 0),
            soundID: "system.default"
        )
        let day = date(2026, 1, 1)
        let holiday = HolidayOverrideSnapshot(
            label: "元日", skipAlarm: true, replacementPresetID: nil)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: date(2026, 1, 1),
            cycleLength: 1, slots: [presetID],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = DayResolverInput(
            manualAssignments: [:],
            holidays: [day: holiday],
            rotations: [rotation],
            presets: [presetID: preset],
            calendar: calendar
        )
        let resolved = DayResolver.resolve(date: day, input: input)
        XCTAssertTrue(resolved.skipsAlarm)
        XCTAssertNil(resolved.fireTime)
    }

    func testRotationAppliesWhenNoManualOrHoliday() {
        let presetID = UUID()
        let preset = ShiftPresetSnapshot(
            id: presetID, name: "Day", colorHex: "#000",
            alarmTime: DateComponents(hour: 6, minute: 30),
            soundID: "system.default"
        )
        let day = date(2026, 5, 12)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: date(2026, 5, 12),
            cycleLength: 1, slots: [presetID],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = DayResolverInput(
            manualAssignments: [:],
            holidays: [:],
            rotations: [rotation],
            presets: [presetID: preset],
            calendar: calendar
        )
        let resolved = DayResolver.resolve(date: day, input: input)
        if case .rotation(let id, let t) = resolved {
            XCTAssertEqual(id, presetID)
            XCTAssertEqual(t?.hour, 6)
            XCTAssertEqual(t?.minute, 30)
        } else {
            XCTFail("Expected rotation")
        }
    }

    func testHigherPriorityRotationWins() {
        let lowID = UUID()
        let highID = UUID()
        let presets: [UUID: ShiftPresetSnapshot] = [
            lowID: ShiftPresetSnapshot(
                id: lowID, name: "Low", colorHex: "#0",
                alarmTime: DateComponents(hour: 5, minute: 0), soundID: "s"),
            highID: ShiftPresetSnapshot(
                id: highID, name: "High", colorHex: "#1",
                alarmTime: DateComponents(hour: 7, minute: 0), soundID: "s"),
        ]
        let day = date(2026, 5, 12)
        let low = RotationPatternSnapshot(
            id: UUID(), name: "low", anchorDate: day, cycleLength: 1, slots: [lowID],
            startDate: nil, endDate: nil, priority: 0, isActive: true)
        let high = RotationPatternSnapshot(
            id: UUID(), name: "high", anchorDate: day, cycleLength: 1, slots: [highID],
            startDate: nil, endDate: nil, priority: 5, isActive: true)
        let input = DayResolverInput(
            manualAssignments: [:], holidays: [:], rotations: [low, high], presets: presets,
            calendar: calendar)
        let resolved = DayResolver.resolve(date: day, input: input)
        if case .rotation(let id, _) = resolved {
            XCTAssertEqual(id, highID)
        } else {
            XCTFail("Expected rotation")
        }
    }
}
