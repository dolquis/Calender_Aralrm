import SwiftData
import XCTest

@testable import ShiftAlarm

@MainActor
final class AlarmSchedulerTests: XCTestCase {
    func testResolverInputCapturesAllSources() async throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar.current

        let preset = ShiftPreset(
            name: "Night", colorHex: "#1E88E5", defaultAlarmHour: 20, defaultAlarmMinute: 0)
        context.insert(preset)

        let day = calendar.startOfDay(for: .now)
        let assignment = DayAssignment(date: day, preset: preset)
        context.insert(assignment)

        let holiday = HolidayOverride(
            date: calendar.date(byAdding: .day, value: 1, to: day)!,
            kind: .publicHoliday,
            label: "Holiday",
            skipAlarm: true
        )
        context.insert(holiday)

        let rotation = RotationPattern(
            name: "r",
            anchorDate: day,
            cycleLength: 1,
            slots: [preset.id]
        )
        context.insert(rotation)
        try context.save()

        let input = await AlarmScheduler.buildResolverInput(context: context, calendar: calendar)
        XCTAssertEqual(input.presets.count, 1)
        XCTAssertEqual(input.manualAssignments.count, 1)
        XCTAssertEqual(input.holidays.count, 1)
        XCTAssertEqual(input.rotations.count, 1)
        XCTAssertEqual(input.rotations.first?.slots.first ?? nil, preset.id)
    }
}
