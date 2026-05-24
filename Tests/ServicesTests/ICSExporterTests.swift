import Foundation
import Testing

@testable import ShiftAlarm

struct ICSExporterTests {

    // MARK: - Fixtures

    private static let dayID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private static let nightID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

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
    @Test
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
        #expect(result.contains("BEGIN:VCALENDAR"))
        #expect(result.contains("END:VCALENDAR"))
        #expect(!result.contains("BEGIN:VEVENT"), "No events expected for all-none days")
    }

    // MARK: - η-U2: required properties present
    @Test
    func testRequiredPropertiesPresent() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.rotation(
            presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        #expect(result.contains("PRODID:-//ShiftAlarm//ja//EN"))
        #expect(result.contains("VERSION:2.0"))
        #expect(result.contains("BEGIN:VEVENT"))
        #expect(result.contains("SUMMARY:昼勤"))
        let events = try ICSTestParser.parse(result)
        #expect(events.count == 1)
    }

    // MARK: - η-U3: SUMMARY escaping
    @Test
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
            resolvedDays: [
                .rotation(presetID: presetID, alarmTime: DateComponents(hour: 6, minute: 0))
            ],
            presets: [presetID: special],
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        #expect(result.contains("SUMMARY:昼\\,夜\\;A\\\\B\\nC"))
    }
    @Test
    func testSummaryEscapesCRLFWithoutBareCarriageReturn() throws {
        let presetID = UUID()
        let special = ShiftPresetSnapshot(
            id: presetID, name: "A\r\nB\rC",
            colorHex: "#000", alarmTime: DateComponents(hour: 6, minute: 0),
            soundID: "s"
        )
        let today = date(2026, 5, 19)
        let result = exporter.export(
            range: today...today,
            resolvedDays: [
                .rotation(presetID: presetID, alarmTime: DateComponents(hour: 6, minute: 0))
            ],
            presets: [presetID: special],
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        #expect(result.contains("SUMMARY:A\\nB\\nC\r\n"))
        #expect(
            !result.contains("SUMMARY:A\r\\nB"), "Escaped SUMMARY must not leave a bare CR")
    }
    @Test
    func testLongSummaryIsFoldedAt75OctetsAndRoundTrips() throws {
        let presetID = UUID()
        let longName = String(repeating: "長いシフト名", count: 8)
        let special = ShiftPresetSnapshot(
            id: presetID, name: longName,
            colorHex: "#000", alarmTime: DateComponents(hour: 6, minute: 0),
            soundID: "s"
        )
        let today = date(2026, 5, 19)
        let result = exporter.export(
            range: today...today,
            resolvedDays: [
                .rotation(presetID: presetID, alarmTime: DateComponents(hour: 6, minute: 0))
            ],
            presets: [presetID: special],
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )

        let physicalLines = result.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(
            physicalLines.allSatisfy { $0.utf8.count <= 75 },
            "Every physical content line must be folded to 75 octets or fewer")
        #expect(
            physicalLines.contains { $0.hasPrefix(" ") },
            "A long SUMMARY should produce at least one continuation line")

        let events = try ICSTestParser.parse(result)
        #expect(events.first?.summary == longName)
    }

    // MARK: - η-U4: skipAlarm day produces no event
    @Test
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
        #expect(!result.contains("BEGIN:VEVENT"))
    }

    // MARK: - η-U6: UID is deterministic
    @Test
    func testUIDIsDeterministic() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.rotation(
            presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
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
            now: today.addingTimeInterval(3600)  // different 'now' should not affect UID
        )
        let e1 = try ICSTestParser.parse(r1)
        let e2 = try ICSTestParser.parse(r2)
        #expect(e1.first?.uid == e2.first?.uid)
    }

    // MARK: - η-U7: UTC conversion (Asia/Tokyo 06:00 → previous day 21:00Z)
    @Test
    func testUTCConversionTokyoSixAM() throws {
        let today = date(2026, 5, 19)  // 2026-05-19 in Asia/Tokyo
        let resolved = ResolvedDay.rotation(
            presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        // Asia/Tokyo UTC+9: 06:00 JST = previous day 21:00 UTC
        #expect(
            result.contains("DTSTART:20260518T210000Z"),
            "Expected DTSTART:20260518T210000Z in:\n\(result)")
        #expect(
            result.contains("DTEND:20260518T213000Z"),
            "Expected DTEND:20260518T213000Z in:\n\(result)")
        #expect(result.contains("X-WR-TIMEZONE:Asia/Tokyo"))
    }
    @Test
    func testExportUsesProvidedTimeZoneForLocalDayBoundaries() throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let today = date(2026, 5, 19)  // 2026-05-19 in Asia/Tokyo
        let resolved = ResolvedDay.rotation(
            presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: utcCalendar,
            timeZone: tokyoTZ,
            now: today
        )
        #expect(
            result.contains("DTSTART:20260518T210000Z"),
            "The exported local day should be interpreted in the provided time zone")
    }

    // MARK: - η-U9: ascending date order
    @Test
    func testEventsInAscendingOrder() throws {
        let start = date(2026, 5, 19)
        let end = date(2026, 5, 20)
        let resolved1 = ResolvedDay.rotation(
            presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let resolved2 = ResolvedDay.rotation(
            presetID: Self.nightID, alarmTime: DateComponents(hour: 22, minute: 0))
        let result = exporter.export(
            range: start...end,
            resolvedDays: [resolved1, resolved2],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: start
        )
        let events = try ICSTestParser.parse(result)
        #expect(events.count == 2)
        #expect(events[0].dtstart < events[1].dtstart)
    }

    // MARK: - CRLF line endings
    @Test
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
        #expect(result.contains("\r\n"), "Output must use CRLF line endings")
    }

    // MARK: - UID suffix
    @Test
    func testUIDHasCorrectSuffix() throws {
        let today = date(2026, 5, 19)
        let resolved = ResolvedDay.rotation(
            presetID: Self.dayID, alarmTime: DateComponents(hour: 6, minute: 0))
        let result = exporter.export(
            range: today...today,
            resolvedDays: [resolved],
            presets: makePresets(),
            calendar: calendar,
            timeZone: tokyoTZ,
            now: today
        )
        let events = try ICSTestParser.parse(result)
        #expect(events.first?.uid.hasSuffix("@shiftalarm.local") == true)
    }
}
