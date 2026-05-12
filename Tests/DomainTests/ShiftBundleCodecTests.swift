import XCTest
@testable import ShiftAlarm

final class ShiftBundleCodecTests: XCTestCase {
    func testRoundTrip() throws {
        let presetID = UUID()
        let day = CalendarDay(year: 2026, month: 5, day: 12)
        let bundle = ShiftBundle(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            presets: [
                ShiftBundle.PresetDTO(
                    id: presetID,
                    name: "夜勤",
                    colorHex: "#1E88E5",
                    defaultAlarmHour: 20,
                    defaultAlarmMinute: 0,
                    soundID: "system.default",
                    note: ""
                )
            ],
            patterns: [
                ShiftBundle.RotationDTO(
                    id: UUID(),
                    name: "4勤2休",
                    anchorDate: day,
                    cycleLength: 6,
                    slots: [presetID, presetID, presetID, presetID, nil, nil],
                    startDate: nil,
                    endDate: nil,
                    priority: 0,
                    isActive: true
                )
            ],
            assignments: [
                ShiftBundle.AssignmentDTO(
                    date: day,
                    presetID: presetID,
                    overrideAlarmHour: 21,
                    overrideAlarmMinute: 30,
                    skipAlarm: false,
                    note: ""
                )
            ],
            overrides: [
                ShiftBundle.OverrideDTO(
                    date: day,
                    kind: .publicHoliday,
                    label: "元日",
                    skipAlarm: true,
                    replacementPresetID: nil
                )
            ]
        )
        let data = try ShiftBundleCodec.encode(bundle)
        let decoded = try ShiftBundleCodec.decode(data)
        XCTAssertEqual(decoded, bundle)
    }

    func testCalendarDayIsStableAcrossTimeZones() throws {
        let exportTZ = TimeZone(identifier: "Asia/Tokyo")!
        let importTZ = TimeZone(identifier: "America/Los_Angeles")!
        var exportCal = Calendar(identifier: .gregorian); exportCal.timeZone = exportTZ
        var importCal = Calendar(identifier: .gregorian); importCal.timeZone = importTZ

        var dc = DateComponents()
        dc.year = 2026; dc.month = 1; dc.day = 1
        let tokyoNewYear = exportCal.date(from: dc)!
        let encoded = CalendarDay(date: tokyoNewYear, calendar: exportCal)!

        XCTAssertEqual(encoded, CalendarDay(year: 2026, month: 1, day: 1))
        let decodedInLA = encoded.date(in: importCal)!
        let parts = importCal.dateComponents([.year, .month, .day], from: decodedInLA)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 1)
        XCTAssertEqual(parts.day, 1)
    }

    func testInvalidPayloadThrows() {
        XCTAssertThrowsError(try ShiftBundleCodec.decode(Data("{not json}".utf8)))
    }

    func testCalendarDayDecoderRejectsImpossibleDates() {
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(CalendarDay.self, from: Data("\"2026-13-40\"".utf8)))
        XCTAssertThrowsError(try decoder.decode(CalendarDay.self, from: Data("\"2026-02-30\"".utf8)))
        XCTAssertThrowsError(try decoder.decode(CalendarDay.self, from: Data("\"2026-00-10\"".utf8)))
        XCTAssertNoThrow(try decoder.decode(CalendarDay.self, from: Data("\"2026-02-28\"".utf8)))
    }
}
