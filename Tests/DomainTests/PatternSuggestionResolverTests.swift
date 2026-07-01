import Foundation
import Testing

@testable import ShiftAlarm

struct PatternSuggestionResolverTests {
    static let dayID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let nightID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let today = makeDate(2026, 5, 18)

    static var gregorianTokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.firstWeekday = 2
        return calendar
    }

    static var windowStart: Date {
        gregorianTokyo.date(byAdding: .day, value: -90, to: today)!
    }

    static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return gregorianTokyo.date(from: components)!
    }

    var calendar: Calendar { Self.gregorianTokyo }

    func makePresets() -> [UUID: ShiftPresetSnapshot] {
        [
            Self.dayID: ShiftPresetSnapshot(
                id: Self.dayID,
                name: "Day",
                colorHex: "#FFB300",
                alarmTime: DateComponents(hour: 6, minute: 0),
                soundID: "system.default"
            ),
            Self.nightID: ShiftPresetSnapshot(
                id: Self.nightID,
                name: "Night",
                colorHex: "#3949AB",
                alarmTime: DateComponents(hour: 22, minute: 0),
                soundID: "system.default"
            ),
        ]
    }

    func dailyAlternateHistory(start: Date, days: Int) -> [Date: DayAssignmentSnapshot] {
        var result: [Date: DayAssignmentSnapshot] = [:]
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let presetID = offset % 2 == 0 ? Self.dayID : Self.nightID
            result[day] = DayAssignmentSnapshot(
                presetID: presetID,
                overrideTime: nil,
                skipAlarm: false,
                note: ""
            )
        }
        return result
    }

    func input(
        assignments: [Date: DayAssignmentSnapshot],
        rotations: [RotationPatternSnapshot] = []
    ) -> DayResolverInput {
        DayResolverInput(
            manualAssignments: assignments,
            holidays: [:],
            rotations: rotations,
            presets: makePresets(),
            calendar: calendar
        )
    }

    func resolver(threshold: Double = 0.15) -> PatternSuggestionResolver {
        PatternSuggestionResolver(driftThreshold: threshold)
    }

    func matchingActivePattern(
        for suggestion: ShiftPatternDetector.SuggestedRotation,
        isActive: Bool = true
    ) -> RotationPatternSnapshot {
        RotationPatternSnapshot(
            id: UUID(),
            name: "Accepted",
            anchorDate: suggestion.anchorDate,
            cycleLength: suggestion.cycleLength,
            slots: suggestion.slots,
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: isActive
        )
    }

    func allDayPattern(id: UUID = UUID()) -> RotationPatternSnapshot {
        RotationPatternSnapshot(
            id: id,
            name: "All Day",
            anchorDate: Self.windowStart,
            cycleLength: 1,
            slots: [Self.dayID],
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: true
        )
    }

    @Test
    func testEmptyInputReturnsNoSuggestion() {
        let result = resolver().resolve(
            input: input(assignments: [:]),
            today: Self.today,
            calendar: calendar
        )

        #expect(result == nil)
    }

    @Test
    func testRepeatingHistoryReturnsNewRotationSuggestion() throws {
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)

        let result = try #require(
            resolver().resolve(
                input: input(assignments: assignments),
                today: Self.today,
                calendar: calendar
            ))

        #expect(result.isDriftUpdate == false)
        #expect(result.replacingPatternID == nil)
        #expect(result.suggestion.cycleLength == 2)
    }

    @Test
    func testDriftedActivePatternReturnsReplacementSuggestion() throws {
        let patternID = UUID()
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)

        let result = try #require(
            resolver().resolve(
                input: input(assignments: assignments, rotations: [allDayPattern(id: patternID)]),
                today: Self.today,
                calendar: calendar
            ))

        #expect(result.isDriftUpdate)
        #expect(result.replacingPatternID == patternID)
        #expect(result.suggestion.cycleLength == 2)
    }

    @Test
    func testDuplicateActivePatternSuppressesSuggestion() throws {
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)
        let baseline = try #require(
            resolver().resolve(
                input: input(assignments: assignments),
                today: Self.today,
                calendar: calendar
            ))
        let acceptedPattern = matchingActivePattern(for: baseline.suggestion)

        let result = resolver().resolve(
            input: input(assignments: assignments, rotations: [acceptedPattern]),
            today: Self.today,
            calendar: calendar
        )

        #expect(result == nil)
    }

    @Test
    func testInactiveDuplicatePatternDoesNotSuppressSuggestion() throws {
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)
        let baseline = try #require(
            resolver().resolve(
                input: input(assignments: assignments),
                today: Self.today,
                calendar: calendar
            ))
        let inactivePattern = matchingActivePattern(for: baseline.suggestion, isActive: false)

        let result = resolver().resolve(
            input: input(assignments: assignments, rotations: [inactivePattern]),
            today: Self.today,
            calendar: calendar
        )

        #expect(result?.isDriftUpdate == false)
        #expect(result?.suggestion.cycleLength == 2)
    }

    @Test
    func testSnoozedFingerprintSuppressesSuggestionUntilDeadline() throws {
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)
        let baseline = try #require(
            resolver().resolve(
                input: input(assignments: assignments),
                today: Self.today,
                calendar: calendar
            ))
        let futureDeadline = calendar.date(byAdding: .day, value: 1, to: Self.today)!

        let result = resolver().resolve(
            input: input(assignments: assignments),
            today: Self.today,
            calendar: calendar,
            snoozedFingerprint: baseline.suggestion.fingerprint,
            snoozedUntil: futureDeadline
        )

        #expect(result == nil)
    }

    @Test
    func testExpiredSnoozeShowsSuggestionAgain() throws {
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)
        let baseline = try #require(
            resolver().resolve(
                input: input(assignments: assignments),
                today: Self.today,
                calendar: calendar
            ))
        let expiredDeadline = calendar.date(byAdding: .day, value: -1, to: Self.today)!

        let result = resolver().resolve(
            input: input(assignments: assignments),
            today: Self.today,
            calendar: calendar,
            snoozedFingerprint: baseline.suggestion.fingerprint,
            snoozedUntil: expiredDeadline
        )

        #expect(result?.suggestion.fingerprint == baseline.suggestion.fingerprint)
    }

    @Test
    func testDifferentSnoozedFingerprintShowsSuggestion() {
        let assignments = dailyAlternateHistory(start: Self.windowStart, days: 90)
        let futureDeadline = calendar.date(byAdding: .day, value: 1, to: Self.today)!

        let result = resolver().resolve(
            input: input(assignments: assignments),
            today: Self.today,
            calendar: calendar,
            snoozedFingerprint: "v1:other",
            snoozedUntil: futureDeadline
        )

        #expect(result?.isDriftUpdate == false)
        #expect(result?.suggestion.cycleLength == 2)
    }
}
