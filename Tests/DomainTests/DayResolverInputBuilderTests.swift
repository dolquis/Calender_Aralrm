import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
struct DayResolverInputBuilderTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }
    @Test
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
        let snapshot = try #require(input.presets[preset.id])
        #expect(snapshot.targetSleepDuration == 7 * 3600)
        #expect(snapshot.bedtimeLeadMinutes == 45)
    }
    @Test
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
        #expect(input.manualAssignments.count == 1)
        #expect(input.manualAssignments[day] != nil)
    }

    @Test
    func testSwapRecordsKeyedByStartOfDay() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let day = calendar.startOfDay(for: .now)
        let timestamp = calendar.date(byAdding: .hour, value: 12, to: day)!
        context.insert(
            SwapRecord(
                date: timestamp,
                kind: .covered,
                counterpartyLabel: "A",
                note: "covered",
                calendar: calendar
            ))
        try context.save()

        let input = DayResolverInputBuilder.make(context: context, calendar: calendar)
        let snapshots = try #require(input.swapRecords[day])
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.kind == .covered)
        #expect(snapshots.first?.counterpartyLabel == "A")
        #expect(snapshots.first?.note == "covered")
    }

    @Test
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
        #expect(input.presets.count == 1)
        #expect(input.holidays.count == 1)
        #expect(input.rotations.count == 1)
    }
}
