import XCTest

@testable import ShiftAlarm

final class SleepSampleWriterTests: XCTestCase {
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

    func testPastWindowsExcludesFutureWakes() {
        let now = Date()
        let past = window(offsetHours: -4)
        let future = window(offsetHours: 4)
        let result = SleepSampleWriter.pastWindows(from: [past, future], now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.wakeTime, past.wakeTime)
    }

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
        XCTAssertEqual(SleepSampleWriter.pastWindows(from: [exact], now: now).count, 1)
    }

    func testPastWindowsReturnsEmptyWhenAllFuture() {
        let now = Date()
        let result = SleepSampleWriter.pastWindows(
            from: [window(offsetHours: 1), window(offsetHours: 24)],
            now: now
        )
        XCTAssertTrue(result.isEmpty)
    }
}
