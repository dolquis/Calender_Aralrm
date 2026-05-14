import XCTest
@testable import ShiftAlarm

final class SleepWindowResolverTests: XCTestCase {
    // Fixed Asia/Tokyo calendar so test dates are deterministic.
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

    private func makePreset(
        id: UUID = UUID(),
        name: String = "Day",
        wakeHour: Int,
        wakeMinute: Int,
        sleepHours: Double = 8,
        leadMinutes: Int = 30
    ) -> (UUID, ShiftPresetSnapshot) {
        let snapshot = ShiftPresetSnapshot(
            id: id,
            name: name,
            colorHex: "#1E88E5",
            alarmTime: DateComponents(hour: wakeHour, minute: wakeMinute),
            soundID: "system.default",
            targetSleepDuration: sleepHours * 3600,
            bedtimeLeadMinutes: leadMinutes
        )
        return (id, snapshot)
    }

    private func makeInput(presets: [UUID: ShiftPresetSnapshot],
                           rotation: RotationPatternSnapshot) -> DayResolverInput {
        DayResolverInput(
            manualAssignments: [:],
            holidays: [:],
            rotations: [rotation],
            presets: presets,
            calendar: calendar
        )
    }

    // MARK: - Basic bedtime calculation

    func testBedtimeIsWakeTimeMinusSleepDuration() {
        let (id, preset) = makePreset(wakeHour: 6, wakeMinute: 0, sleepHours: 8, leadMinutes: 0)
        let day = date(2026, 5, 20)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)

        XCTAssertEqual(windows.count, 1)
        let w = windows[0]
        // Wake = 06:00, sleep 8h → bedtime = 22:00 previous night
        let expectedBedtime = calendar.date(byAdding: .hour, value: -8, to: w.wakeTime)!
        XCTAssertEqual(w.bedtime, expectedBedtime)
    }

    func testWakeTimeMatchesPresetAlarmTime() {
        let (id, preset) = makePreset(wakeHour: 5, wakeMinute: 30)
        let day = date(2026, 5, 21)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)

        XCTAssertEqual(windows.count, 1)
        let components = calendar.dateComponents([.hour, .minute], from: windows[0].wakeTime)
        XCTAssertEqual(components.hour, 5)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - Night-shift crossover (wake next calendar day)

    func testNightShiftBedtimeIsBeforeWake() {
        // Night shift: wake at 08:00 the following morning.
        // With 9h sleep target the bedtime should be 23:00 the night before.
        let (id, preset) = makePreset(wakeHour: 8, wakeMinute: 0, sleepHours: 9, leadMinutes: 0)
        let day = date(2026, 5, 22)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)

        XCTAssertEqual(windows.count, 1)
        let w = windows[0]
        XCTAssertLessThan(w.bedtime, w.wakeTime, "bedtime must precede wakeTime")
        let gap = w.wakeTime.timeIntervalSince(w.bedtime)
        XCTAssertEqual(gap, 9 * 3600, accuracy: 1)
    }

    // MARK: - Multiple days sorted by wakeTime

    func testWindowsSortedByWakeTime() {
        let (idA, presetA) = makePreset(id: UUID(), name: "Early", wakeHour: 5, wakeMinute: 0, leadMinutes: 0)
        let (idB, presetB) = makePreset(id: UUID(), name: "Late",  wakeHour: 9, wakeMinute: 0, leadMinutes: 0)
        let day1 = date(2026, 5, 23) // will get Early
        let day2 = date(2026, 5, 24) // will get Late
        // Two-slot rotation: Early on day1, Late on day2
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day1,
            cycleLength: 2, slots: [idA, idB],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [idA: presetA, idB: presetB], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day1, day2], input: input)

        XCTAssertEqual(windows.count, 2)
        XCTAssertLessThanOrEqual(windows[0].wakeTime, windows[1].wakeTime)
    }

    // MARK: - Days without an alarm are omitted

    func testDayWithNoAlarmIsOmitted() {
        // Rotation has a nil slot on day2 (rest day).
        let (id, preset) = makePreset(wakeHour: 6, wakeMinute: 0, leadMinutes: 0)
        let day1 = date(2026, 5, 25)
        let day2 = date(2026, 5, 26)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day1,
            cycleLength: 2, slots: [id, nil],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day1, day2], input: input)

        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(calendar.startOfDay(for: windows[0].date), calendar.startOfDay(for: day1))
    }

    // MARK: - Bedtime reminder fire date

    func testReminderFireDateIsLeadMinutesBeforeBedtime() {
        let (id, preset) = makePreset(wakeHour: 6, wakeMinute: 0, sleepHours: 8, leadMinutes: 30)
        let day = date(2026, 5, 27)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)

        XCTAssertEqual(windows.count, 1)
        let w = windows[0]
        XCTAssertNotNil(w.reminderFireDate)
        let leadInterval = w.bedtime.timeIntervalSince(w.reminderFireDate!)
        XCTAssertEqual(leadInterval, 30 * 60, accuracy: 1)
    }

    func testNoReminderWhenLeadIsZero() {
        let (id, preset) = makePreset(wakeHour: 6, wakeMinute: 0, sleepHours: 8, leadMinutes: 0)
        let day = date(2026, 5, 28)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)

        XCTAssertEqual(windows.count, 1)
        XCTAssertNil(windows[0].reminderFireDate)
    }

    // MARK: - Holiday skip

    func testHolidaySkipOmitsWindowForThatDay() {
        let (id, preset) = makePreset(wakeHour: 6, wakeMinute: 0, leadMinutes: 0)
        let day = date(2026, 5, 29)
        let holiday = HolidayOverrideSnapshot(label: "休日", skipAlarm: true, replacementPresetID: nil)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = DayResolverInput(
            manualAssignments: [:],
            holidays: [calendar.startOfDay(for: day): holiday],
            rotations: [rotation],
            presets: [id: preset],
            calendar: calendar
        )
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)
        XCTAssertTrue(windows.isEmpty)
    }

    // MARK: - Short sleep preset

    func testShortSleepPreset() {
        // Paramedic nap: 4h sleep, wake at 14:00 → bedtime 10:00
        let (id, preset) = makePreset(wakeHour: 14, wakeMinute: 0, sleepHours: 4, leadMinutes: 0)
        let day = date(2026, 5, 30)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: day,
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [day], input: input)

        XCTAssertEqual(windows.count, 1)
        let components = calendar.dateComponents([.hour, .minute], from: windows[0].bedtime)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
    }

    // MARK: - Empty input

    func testEmptyDatesReturnsEmptyWindows() {
        let (id, preset) = makePreset(wakeHour: 6, wakeMinute: 0)
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "r", anchorDate: date(2026, 6, 1),
            cycleLength: 1, slots: [id],
            startDate: nil, endDate: nil, priority: 0, isActive: true
        )
        let input = makeInput(presets: [id: preset], rotation: rotation)
        let windows = SleepWindowResolver.resolve(dates: [], input: input)
        XCTAssertTrue(windows.isEmpty)
    }
}
