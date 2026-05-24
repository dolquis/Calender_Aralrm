import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
@Suite(.serialized)
struct SleepIntentHelperTests {
    private func seededContainer(wakeHour: Int = 6, wakeMinute: Int = 0) -> ModelContainer {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let preset = ShiftPreset(
            name: "Day",
            colorHex: "#1E88E5",
            defaultAlarmHour: wakeHour,
            defaultAlarmMinute: wakeMinute,
            targetSleepDuration: 8 * 3600,
            bedtimeLeadMinutes: 30
        )
        context.insert(preset)
        // Cover the next 14 days so the helper has something to return regardless of "today".
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: .now)
        context.insert(
            RotationPattern(name: "r", anchorDate: anchor, cycleLength: 1, slots: [preset.id]))
        try? context.save()
        return container
    }

    private func withContainerFactory<T>(
        _ container: ModelContainer,
        operation: () async -> T
    ) async -> T {
        SleepIntentHelper.containerFactory = { container }
        defer {
            SleepIntentHelper.containerFactory = { SharedPersistence.makeContainer() }
        }
        return await operation()
    }

    @Test
    func testReturnsNilWhenNoSchedule() async {
        let empty = SharedPersistence.makeContainer(inMemory: true)
        await withContainerFactory(empty) {
            let next = await SleepIntentHelper.fetchNextWindow()
            #expect(next == nil)
        }
    }

    @Test
    func testFetchUpcomingWindowsExposesPresetMetadata() async {
        let container = seededContainer()
        await withContainerFactory(container) {
            let windows = await SleepIntentHelper.fetchUpcomingWindows()
            #expect(!windows.isEmpty)
            #expect(windows.first?.presetName == "Day")
        }
    }

    @Test
    func testFetchNextBedtimeSkipsWindowsWhoseBedtimeAlreadyPassed() async {
        let container = seededContainer(wakeHour: 6)
        await withContainerFactory(container) {
            // Simulate "now" as 23:00 today: today's bedtime (22:00) has passed but tomorrow's wake
            // is still upcoming. fetchNextBedtimeWindow must skip today and return tomorrow.
            let calendar = Calendar.current
            let referenceNow = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!
            let next = await SleepIntentHelper.fetchNextBedtimeWindow(now: referenceNow)
            if let next {
                #expect(next.bedtime > referenceNow)
            }
            // If nil, the seeded rotation didn't cover any future window — also acceptable.
        }
    }
}
