import XCTest

@testable import ShiftAlarm

final class ShiftPatternDetectorTests: XCTestCase {

    // MARK: - Fixed UUIDs / dates

    static let dayID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let nightID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let eveningID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    // today = 2026-05-18 (frozen)
    static let today = makeDate(2026, 5, 18)

    // windowStart for windowDays=90: today - 90 days = 2026-02-17
    static var windowStart: Date {
        var c = gregorianTokyo
        c.firstWeekday = 2
        return c.date(byAdding: .day, value: -90, to: today)!
    }

    static var gregorianTokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        c.firstWeekday = 2
        return c
    }

    static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return gregorianTokyo.date(from: dc)!
    }

    var calendar: Calendar { Self.gregorianTokyo }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date { Self.makeDate(y, m, d) }

    // MARK: - Fixture helpers

    /// Fills `count` consecutive days from `start` with alternating weeks (dayID / nightID per week).
    func alternateWeeksHistory(start: Date, days: Int) -> [Date: DayAssignmentSnapshot] {
        var result: [Date: DayAssignmentSnapshot] = [:]
        for i in 0..<days {
            let day = calendar.date(byAdding: .day, value: i, to: start)!
            let weekIndex = i / 7
            let pid: UUID = weekIndex % 2 == 0 ? Self.dayID : Self.nightID
            result[day] = DayAssignmentSnapshot(
                presetID: pid, overrideTime: nil, skipAlarm: false, note: "")
        }
        return result
    }

    /// Fills `days` consecutive days with D/N/D/N... alternation.
    func dailyAlternateHistory(start: Date, days: Int) -> [Date: DayAssignmentSnapshot] {
        var result: [Date: DayAssignmentSnapshot] = [:]
        for i in 0..<days {
            let day = calendar.date(byAdding: .day, value: i, to: start)!
            let pid: UUID = i % 2 == 0 ? Self.dayID : Self.nightID
            result[day] = DayAssignmentSnapshot(
                presetID: pid, overrideTime: nil, skipAlarm: false, note: "")
        }
        return result
    }

    /// 22-day pattern: [D,D,off,off,N,N,off,off,D,D,D,D,off,off,off,off,D,D,D,D,off,off] × cycles.
    func history22Day(start: Date, cycles: Int) -> [Date: DayAssignmentSnapshot] {
        let pattern: [UUID?] = [
            Self.dayID, Self.dayID, nil, nil, Self.nightID, Self.nightID, nil, nil,
            Self.dayID, Self.dayID, Self.dayID, Self.dayID, nil, nil, nil, nil,
            Self.dayID, Self.dayID, Self.dayID, Self.dayID, nil, nil,
        ]
        var result: [Date: DayAssignmentSnapshot] = [:]
        for cycle in 0..<cycles {
            for (i, pid) in pattern.enumerated() {
                let day = calendar.date(byAdding: .day, value: cycle * 22 + i, to: start)!
                if let pid {
                    result[day] = DayAssignmentSnapshot(
                        presetID: pid, overrideTime: nil, skipAlarm: false, note: "")
                } else {
                    result[day] = DayAssignmentSnapshot(
                        presetID: nil, overrideTime: nil, skipAlarm: true, note: "")
                }
            }
        }
        return result
    }

    /// Replaces roughly 1/`errorEvery` entries with an alternate preset UUID.
    func addNoise(
        to base: [Date: DayAssignmentSnapshot], errorEvery: Int
    ) -> [Date: DayAssignmentSnapshot] {
        let noiseOffsets = [
            3, 8, 10, 11, 13, 17, 18, 23, 26, 27, 29, 30, 32, 34,
            37, 40, 41, 43, 48, 51, 57, 65, 69, 70, 71, 75, 80, 83,
        ]
        var result = base
        let keys = base.keys.sorted()
        let noiseCount = keys.count / errorEvery
        for offset in noiseOffsets.prefix(noiseCount) where offset < keys.count {
            result[keys[offset]] = DayAssignmentSnapshot(
                presetID: Self.eveningID, overrideTime: nil, skipAlarm: false, note: "")
        }
        return result
    }

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
            Self.eveningID: ShiftPresetSnapshot(
                id: Self.eveningID,
                name: "Evening",
                colorHex: "#00897B",
                alarmTime: DateComponents(hour: 14, minute: 0),
                soundID: "system.default"
            ),
        ]
    }

    // MARK: - α-U1: empty input

    func testEmptyInputReturnsNil() {
        let detector = ShiftPatternDetector()
        XCTAssertNil(
            detector.detect(
                manualAssignments: [:], presets: makePresets(),
                today: Self.today, calendar: calendar
            ))
    }

    // MARK: - α-U2: too little data for any cycle (density fails)

    func testSevenDaysOfDataReturnsNil() {
        // 7 days => density < 0.5 for any cycle length with windowDays=90
        let start = date(2026, 5, 11)
        let a = alternateWeeksHistory(start: start, days: 7)
        let detector = ShiftPatternDetector()
        XCTAssertNil(
            detector.detect(
                manualAssignments: a, presets: makePresets(),
                today: Self.today, calendar: calendar
            ))
    }

    // MARK: - α-U3: 14-day alternate-week cycle wins over P=2

    func testAlternateWeeks14DayCycle() {
        // 84 days (6 complete 14-day cycles) starting at windowStart.
        // P=2 match rate ≈ 0.5 (fails threshold), P=14 match rate = 1.0.
        let a = alternateWeeksHistory(start: Self.windowStart, days: 84)
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cycleLength, 14)
        XCTAssertEqual(result?.confidence ?? 0, 1.0, accuracy: 0.001)
    }

    // MARK: - α-U4: daily D/N alternation → P=2 wins (tiebreak: shorter cycle)

    func testDailyAlternateCycleLengthTwo() {
        // 60 days gives enough density for P=2 (30 obs / 45 expected slot days ≈ 0.67 > 0.5).
        // Both P=2 and P=14 would score 1.0; P=2 wins via tiebreak.
        let a = dailyAlternateHistory(start: Self.windowStart, days: 60)
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cycleLength, 2)
        let slots = result!.slots
        XCTAssertEqual(slots.count, 2)
        XCTAssertTrue(slots.contains(Self.dayID))
        XCTAssertTrue(slots.contains(Self.nightID))
    }

    // MARK: - α-U5: 22-day complex pattern

    func testComplexPattern22DayCycle() {
        // 4 cycles × 22 days = 88 days; all slots are dense enough even with the 90-day window tail.
        let a = history22Day(start: Self.windowStart, cycles: 4)
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cycleLength, 22)
    }

    // MARK: - α-U6: too much noise → nil

    func testHighNoiseBelowThreshold() {
        let base = alternateWeeksHistory(start: Self.windowStart, days: 84)
        let noisy = addNoise(to: base, errorEvery: 3)  // ~33% wrong
        let detector = ShiftPatternDetector()
        XCTAssertNil(
            detector.detect(
                manualAssignments: noisy, presets: makePresets(),
                today: Self.today, calendar: calendar
            ))
    }

    // MARK: - α-U7: lower threshold lets noisy data through

    func testCustomLowerThresholdAllowsDetection() {
        let base = alternateWeeksHistory(start: Self.windowStart, days: 84)
        let noisy = addNoise(to: base, errorEvery: 3)
        var config = ShiftPatternDetector.Configuration()
        config.minMatchRate = 0.5
        let detector = ShiftPatternDetector(configuration: config)
        XCTAssertNotNil(
            detector.detect(
                manualAssignments: noisy, presets: makePresets(),
                today: Self.today, calendar: calendar
            ))
    }

    // MARK: - α-U8: slot UUIDs are not relabelled

    func testSlotUUIDsPreserved() {
        // 3-day cycle [D, N, E] × 30 = 90 entries
        var a: [Date: DayAssignmentSnapshot] = [:]
        let cycle: [UUID] = [Self.dayID, Self.nightID, Self.eveningID]
        for i in 0..<90 {
            let day = calendar.date(byAdding: .day, value: i, to: Self.windowStart)!
            let pid = cycle[i % 3]
            a[day] = DayAssignmentSnapshot(
                presetID: pid, overrideTime: nil, skipAlarm: false, note: "")
        }
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cycleLength, 3)
        let slots = result!.slots.compactMap { $0 }
        XCTAssertTrue(slots.contains(Self.dayID))
        XCTAssertTrue(slots.contains(Self.nightID))
        XCTAssertTrue(slots.contains(Self.eveningID))
    }

    // MARK: - α-U9: explicit off (skipAlarm) maps to nil slot

    func testOffDayMapsToNilSlot() {
        // 4-day cycle: day / off / night / off
        var a: [Date: DayAssignmentSnapshot] = [:]
        let patternSize = 4
        // 23 cycles × 4 = 92 days; the detector only consumes the 90-day window.
        for i in 0..<(patternSize * 23) {
            let day = calendar.date(byAdding: .day, value: i, to: Self.windowStart)!
            switch i % patternSize {
            case 0:
                a[day] = DayAssignmentSnapshot(
                    presetID: Self.dayID, overrideTime: nil, skipAlarm: false, note: "")
            case 1:
                a[day] = DayAssignmentSnapshot(
                    presetID: nil, overrideTime: nil, skipAlarm: true, note: "")
            case 2:
                a[day] = DayAssignmentSnapshot(
                    presetID: Self.nightID, overrideTime: nil, skipAlarm: false, note: "")
            case 3:
                a[day] = DayAssignmentSnapshot(
                    presetID: nil, overrideTime: nil, skipAlarm: true, note: "")
            default:
                break
            }
        }
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cycleLength, 4)
        XCTAssertTrue(result!.slots.contains(nil), "Expected at least one nil (off) slot")
    }

    func testMissingPresetAssignmentsAreIgnored() {
        let staleID = UUID(uuidString: "00000000-0000-0000-0000-00000000DEAD")!
        var a: [Date: DayAssignmentSnapshot] = [:]
        for i in 0..<90 {
            let day = calendar.date(byAdding: .day, value: i, to: Self.windowStart)!
            a[day] = DayAssignmentSnapshot(
                presetID: staleID, overrideTime: nil, skipAlarm: false, note: "")
        }
        let detector = ShiftPatternDetector()
        XCTAssertNil(
            detector.detect(
                manualAssignments: a,
                presets: makePresets(),
                today: Self.today,
                calendar: calendar
            ), "Deleted/stale preset IDs should not produce a rotation with dangling slots")
    }

    func testPartialCycleUsesSlotSpecificDensity() {
        // A single 35-day block should not be accepted for P=35: slots that appear
        // three times in the 90-day window only have one observation (1/3 < 0.5).
        var a: [Date: DayAssignmentSnapshot] = [:]
        for i in 0..<35 {
            let day = calendar.date(byAdding: .day, value: i, to: Self.windowStart)!
            a[day] = DayAssignmentSnapshot(
                presetID: Self.dayID, overrideTime: nil, skipAlarm: false, note: "")
        }
        let detector = ShiftPatternDetector()
        XCTAssertNil(
            detector.detect(
                manualAssignments: a,
                presets: makePresets(),
                today: Self.today,
                calendar: calendar
            ), "Density must be measured against each slot's actual occurrences in the window")
    }

    // MARK: - α-U11: windowDays boundary

    func testWindowDaysBoundaryExcludes91DaysAgo() {
        // Build exactly 90 days of clean D/N alternation within the window.
        let a90 = dailyAlternateHistory(start: Self.windowStart, days: 90)
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a90, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result, "90-day window should detect the 2-day cycle")

        // Adding an outlier 91 days before today (outside window) should not break detection.
        let outside = calendar.date(byAdding: .day, value: -91, to: Self.today)!
        var withOutlier = a90
        withOutlier[outside] = DayAssignmentSnapshot(
            presetID: Self.dayID, overrideTime: nil, skipAlarm: false, note: "")
        let result2 = detector.detect(
            manualAssignments: withOutlier, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result2, "Extra day outside window should not break detection")
    }

    // MARK: - α-U12: anchorDate is always a Monday

    func testAnchorDateIsMonday() {
        // 84 days of 14-day alternating history; the anchor must be the first Monday
        // >= windowStart regardless of which weekday windowStart falls on.
        let a = alternateWeeksHistory(start: Self.windowStart, days: 84)
        let detector = ShiftPatternDetector()
        let result = detector.detect(
            manualAssignments: a, presets: makePresets(),
            today: Self.today, calendar: calendar
        )
        XCTAssertNotNil(result)
        // weekday 2 = Monday in Gregorian (Sun=1, Mon=2, ..., Sat=7)
        XCTAssertEqual(
            calendar.component(.weekday, from: result!.anchorDate), 2,
            "anchorDate should be a Monday")
    }

    // MARK: - Fingerprint determinism

    func testFingerprintIsDeterministic() {
        let a = alternateWeeksHistory(start: Self.windowStart, days: 84)
        let detector = ShiftPatternDetector()
        let r1 = detector.detect(
            manualAssignments: a, presets: makePresets(), today: Self.today, calendar: calendar)
        let r2 = detector.detect(
            manualAssignments: a, presets: makePresets(), today: Self.today, calendar: calendar)
        XCTAssertEqual(r1?.fingerprint, r2?.fingerprint)
        XCTAssertFalse(r1?.fingerprint.isEmpty ?? true)
    }

    // MARK: - A1 Drift detection

    private func makeAllDayPattern() -> RotationPatternSnapshot {
        RotationPatternSnapshot(
            id: UUID(),
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

    // α-U13: mismatch rate below threshold → detectDrift returns nil
    func testDriftBelowThresholdReturnsNil() {
        let pattern = makeAllDayPattern()
        // Last 30 days all assign dayID — matches the all-day pattern, 0 mismatches.
        var assignments: [Date: DayAssignmentSnapshot] = [:]
        for i in 0..<30 {
            let day = calendar.date(byAdding: .day, value: i - 30, to: Self.today)!
            assignments[day] = DayAssignmentSnapshot(
                presetID: Self.dayID, overrideTime: nil, skipAlarm: false, note: "")
        }
        let detector = ShiftPatternDetector()
        let result = detector.detectDrift(
            pattern: pattern,
            recentManualAssignments: assignments,
            presets: makePresets(),
            today: Self.today,
            calendar: calendar,
            threshold: 0.15
        )
        XCTAssertNil(result, "Mismatch rate 0% is below threshold; should not suggest update")
    }

    // α-U14: mismatch rate above threshold → detectDrift calls detect() and returns a suggestion
    func testDriftAboveThresholdReturnsNewSuggestion() {
        // Pattern claims every day is dayID (1-slot cycle).
        let pattern = makeAllDayPattern()
        // Provide 90 days of alternating dayID/nightID history so detect() finds a 2-day cycle.
        var assignments: [Date: DayAssignmentSnapshot] = [:]
        for i in 0..<90 {
            let day = calendar.date(byAdding: .day, value: i - 90, to: Self.today)!
            let pid: UUID = i % 2 == 0 ? Self.dayID : Self.nightID
            assignments[day] = DayAssignmentSnapshot(
                presetID: pid, overrideTime: nil, skipAlarm: false, note: "")
        }
        // ~50% of the 30-day window mismatches the all-day pattern → well above 15% threshold.
        let detector = ShiftPatternDetector()
        let result = detector.detectDrift(
            pattern: pattern,
            recentManualAssignments: assignments,
            presets: makePresets(),
            today: Self.today,
            calendar: calendar,
            threshold: 0.15
        )
        XCTAssertNotNil(
            result, "50% mismatch rate exceeds threshold; a new suggestion should be returned")
        if let r = result {
            // The new suggestion should describe a 2-day cycle, not the original 1-day cycle.
            XCTAssertEqual(r.cycleLength, 2)
        }
    }
}
