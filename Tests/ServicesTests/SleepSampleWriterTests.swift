import Foundation
import Testing

@testable import ShiftAlarm

struct SleepSampleWriterTests {
    private func window(
        offsetHours: Double, sleepHours: Double = 8, presetName: String = "Day"
    ) -> SleepWindow {
        let wake = Date().addingTimeInterval(offsetHours * 3600)
        return SleepWindow(
            date: Calendar.current.startOfDay(for: wake),
            wakeTime: wake,
            bedtime: wake.addingTimeInterval(-sleepHours * 3600),
            reminderFireDate: nil,
            presetID: UUID(),
            presetName: presetName
        )
    }
    @Test
    func testPastWindowsExcludesFutureWakes() {
        let now = Date()
        let past = window(offsetHours: -4)
        let future = window(offsetHours: 4)
        let result = SleepSampleWriter.pastWindows(from: [past, future], now: now)
        #expect(result.count == 1)
        #expect(result.first?.wakeTime == past.wakeTime)
    }
    @Test
    func testPastWindowsIncludesWindowEndingExactlyNow() {
        let now = Date()
        let exact = SleepWindow(
            date: Calendar.current.startOfDay(for: now),
            wakeTime: now,
            bedtime: now.addingTimeInterval(-8 * 3600),
            reminderFireDate: nil,
            presetID: UUID(),
            presetName: "Now"
        )
        #expect(SleepSampleWriter.pastWindows(from: [exact], now: now).count == 1)
    }
    @Test
    func testPastWindowsReturnsEmptyWhenAllFuture() {
        let now = Date()
        let result = SleepSampleWriter.pastWindows(
            from: [window(offsetHours: 1), window(offsetHours: 24)],
            now: now
        )
        #expect(result.isEmpty)
    }
}
