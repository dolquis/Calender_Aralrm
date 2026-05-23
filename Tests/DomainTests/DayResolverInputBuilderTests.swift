import SwiftData
import XCTest

@testable import ShiftAlarm

@MainActor
final class DayResolverInputBuilderTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    func testPropagatesSleepFieldsFromPreset() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let preset = ShiftPreset(
            name: "Night",
            colorHex: "#1E88E5",
            defaultAlarmHour: 6,
            defaultAlarmMinute: 0,
            targetSleepDuration: 7 * 3600,
            bedtimeLeadMinutes: 45
        )
        context.insert(preset)
        try context.save()

        let input = DayResolverInputBuilder.make(context: context, calendar: calendar)
        let snapshot = try XCTUnwrap(input.presets[preset.id])
        XCTAssertEqual(snapshot.targetSleepDuration, 7 * 3600)
        XCTAssertEqual(snapshot.bedtimeLeadMinutes, 45)
    }

    func testAssignmentsKeyedByStartOfDay() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let preset = ShiftPreset(name: "Day", colorHex: "#1E88E5")
        context.insert(preset)

        // Two assignments on the same calendar day at different timestamps collapse to one key.
        let day = calendar.startOfDay(for: .now)
        let earlyTimestamp = calendar.date(byAdding: .hour, value: 1, to: day)!
        let lateTimestamp = calendar.date(byAdding: .hour, value: 23, to: day)!
        context.insert(DayAssignment(date: earlyTimestamp, preset: preset, note: "early"))
        context.insert(DayAssignment(date: lateTimestamp, preset: preset, note: "late"))
        try context.save()

        let input = DayResolverInputBuilder.make(context: context, calendar: calendar)
        XCTAssertEqual(input.manualAssignments.count, 1)
        XCTAssertNotNil(input.manualAssignments[day])
    }

    func testInputMirrorsModelLayer() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let preset = ShiftPreset(name: "P", colorHex: "#1E88E5")
        context.insert(preset)
        let day = calendar.startOfDay(for: .now)
        context.insert(
            HolidayOverride(date: day, kind: .publicHoliday, label: "Holiday", skipAlarm: true))
        context.insert(
            RotationPattern(name: "r", anchorDate: day, cycleLength: 1, slots: [preset.id]))
        try context.save()

        let input = DayResolverInputBuilder.make(context: context, calendar: calendar)
        XCTAssertEqual(input.presets.count, 1)
        XCTAssertEqual(input.holidays.count, 1)
        XCTAssertEqual(input.rotations.count, 1)
    }
}
