import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
struct AlarmSchedulerTests {
    @Test
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
        #expect(input.presets.count == 1)
        #expect(input.manualAssignments.count == 1)
        #expect(input.holidays.count == 1)
        #expect(input.rotations.count == 1)
        #expect((input.rotations.first?.slots.first ?? nil) == preset.id)
    }
}
