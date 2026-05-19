import XCTest
@testable import ShiftAlarm

final class ICSExporterTests: XCTestCase {

    // MARK: - Fixtures

    private static let dayID   = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private static let nightID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

    private var tokyoTZ: TimeZone { TimeZone(identifier: "Asia/Tokyo")! }
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tokyoTZ
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tokyoTZ
        return c.date(from: dc)!
    }

    private func makePresets() -> [UUID: ShiftPresetSnapshot] {
        [
            Self.dayID: ShiftPresetSnapshot(
                id: Self.dayID, name: "昼勤", colorHex: "#FFB300",
                alarmTime: DateComponents(hour: 6, minute: 0),
                soundID: "system.default"
            ),
            Self.nightID: ShiftPresetSnapshot(
                id: Self.nightID, name: "夜勤", colorHex: "#3949AB",
                alarmTime: DateComponents(hour: 22, minute: 0),
                soundID: "system.default"
            ),
        ]
    }

    private let exporter = ICSExporter()

    // MARK: - η-U1: zero events → header and footer only

    func testEmptyRangeProducesNoEvents() {
        let today = date(2026, 5, 19)
        let result = exporter.export(
            range: today...today,
            resolvedDays: [.none],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        XCTAssertTrue(result.contains("BEGIN:VCALENDAR"))
        XCTAssertTrue(result.contains("END:VCALENDAR"))
        XCTAssertFalse(result.contains("BEGIN:VEVENT"), "No events expected for all-none days")
    }

    // MARK: - η-U2: required properties present

    func testRequiredPropertiesPresent() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.rotation(presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        XCTAssertTrue(result.contains("PRODID:-//ShiftAlarm//ja//EN"))
        XCTAssertTrue(result.contains("VERSION:2.0"))
        XCTAssertTrue(result.contains("BEGIN:VEVENT"))
        XCTAssertTrue(result.contains("SUMMARY:昼勤"))
        let events = try ICSTestParser.parse(result)
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - η-U3: SUMMARY escaping

    func testSummaryEscaping() throws {
        let presetID = UUID()
        let special = ShiftPresetSnapshot(
            id: presetID, name: "昼,夜;A\\B\nC",
            colorHex: "#000", alarmTime: DateComponents(hour: 6, minute: 0),
            soundID: "s"
        )
        let today = date(2026, 5, 19)
        let result = exporter.export(
            range: today...today,
            resolvedDays: [.rotation(presetID: presetID, alarmTime: DateComponents(hour: 6, minute: 0))],
            presets: [presetID: special],
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        XCTAssertTrue(result.contains("SUMMARY:昼\\,夜\\;A\\\\B\\nC"))
    }

    // MARK: - η-U4: skipAlarm day produces no event

    func testSkipAlarmExcluded() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.manual(
            presetID: Self.dayID,
            alarmTime: DateComponents(hour: 6, minute: 0),
            skip: true,
            note: ""
        )
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        XCTAssertFalse(result.contains("BEGIN:VEVENT"))
    }

    // MARK: - η-U6: UID is deterministic

    func testUIDIsDeterministic() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.rotation(presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let r1 = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        let r2 = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today.addingTimeInterval(3600) // different 'now' should not affect UID
        )
        let e1 = try ICSTestParser.parse(r1)
        let e2 = try ICSTestParser.parse(r2)
        XCTAssertEqual(e1.first?.uid, e2.first?.uid)
    }

    // MARK: - η-U7: UTC conversion (Asia/Tokyo 06:00 → previous day 21:00Z)

    func testUTCConversionTokyoSixAM() throws {
        let today = date(2026, 5, 19) // 2026-05-19 in Asia/Tokyo
        let resolved = ResolvedDay.rotation(presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        // Asia/Tokyo UTC+9: 06:00 JST = previous day 21:00 UTC
        XCTAssertTrue(result.contains("DTSTART:20260518T210000Z"),
                      "Expected DTSTART:20260518T210000Z in:\n\(result)")
        XCTAssertTrue(result.contains("DTEND:20260518T213000Z"),
                      "Expected DTEND:20260518T213000Z in:\n\(result)")
        XCTAssertTrue(result.contains("X-WR-TIMEZONE:Asia/Tokyo"))
    }

    // MARK: - η-U9: ascending date order

    func testEventsInAscendingOrder() throws {
        let start = date(2026, 5, 19)
        let end = date(2026, 5, 20)
        let resolved1 = ResolvedDay.rotation(presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let resolved2 = ResolvedDay.rotation(presetID: Self.nightID, alarmTime: DateComponents(hour: 22, minute: 0))
        let result = exporter.export(
            range: start...end,
            resolvedDays: [resolved1, resolved2],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: start
        )
        let events = try ICSTestParser.parse(result)
        XCTAssertEqual(events.count, 2)
        XCTAssertLessThan(events[0].dtstart, events[1].dtstart)
    }

    // MARK: - CRLF line endings

    func testCRLFLineEndings() {
        let today = date(2026, 5, 19)
        let result = exporter.export(
            range: today...today,
            resolvedDays: [.none],
            presets: [:],
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        XCTAssertTrue(result.contains("\r\n"), "Output must use CRLF line endings")
    }

    // MARK: - UID suffix

    func testUIDHasCorrectSuffix() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.rotation(presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        let events = try ICSTestParser.parse(result)
        XCTAssertTrue(events.first?.uid.hasSuffix("@shiftalarm.local") == true)
    }
}
