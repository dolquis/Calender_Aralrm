import Foundation
import Testing

@testable import ShiftAlarm

struct VacationAwareRotationTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private var slotIDs: [UUID] {
        (0..<14).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0 + 1))! }
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return calendar.date(from: dc)!
    }

    private func presets(
        ids: [UUID],
        overrides: [Int: CrossVacationPolicy] = [:]
    ) -> [UUID: ShiftPresetSnapshot] {
        ids.enumerated().reduce(into: [:]) { result, entry in
            let (index, id) = entry
            result[id] = ShiftPresetSnapshot(
                id: id,
                name: "slot-\(index)",
                colorHex: "#1E88E5",
                alarmTime: DateComponents(hour: index < 7 ? 6 : 17, minute: 0),
                soundID: "system.default",
                crossVacationPolicy: overrides[index]
            )
        }
    }

    private func pattern(
        ids: [UUID],
        policy: CrossVacationPolicy = .invert,
        dayStartSlotIndex: Int? = nil,
        startDate: Date? = nil,
        slots: [UUID?]? = nil,
        cycleLength: Int? = nil
    ) -> RotationPatternSnapshot {
        let slotValues = slots ?? ids.map { Optional($0) }
        return RotationPatternSnapshot(
            id: UUID(),
            name: "baseline",
            anchorDate: date(2026, 5, 4),
            cycleLength: cycleLength ?? slotValues.count,
            slots: slotValues,
            startDate: startDate,
            endDate: nil,
            priority: 0,
            isActive: true,
            crossVacationPolicy: policy,
            dayStartSlotIndex: dayStartSlotIndex
        )
    }

    private func vacation(_ start: Date, _ end: Date) -> VacationPeriodSnapshot {
        VacationPeriodSnapshot(startDate: start, endDate: end, label: "Vacation")
    }

    @Test
    func testNoVacationMatchesBaseExpander() {
        let ids = slotIDs
        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids),
            vacations: [],
            presets: presets(ids: ids),
            calendar: calendar
        )

        #expect(result == ids[7])
    }

    @Test
    func testVacationDaySuppressesRotationAlarm() {
        let ids = slotIDs
        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 14),
            pattern: pattern(ids: ids),
            vacations: [vacation(date(2026, 8, 13), date(2026, 8, 16))],
            presets: presets(ids: ids),
            calendar: calendar
        )

        #expect(result == nil)
    }

    @Test
    func testInvertContinueAndResetPoliciesUseFixedVector() {
        let ids = slotIDs
        let vacation = vacation(date(2026, 8, 13), date(2026, 8, 16))
        let allPresets = presets(ids: ids)

        let invert = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .invert),
            vacations: [vacation],
            presets: allPresets,
            calendar: calendar
        )
        let continued = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .continue),
            vacations: [vacation],
            presets: allPresets,
            calendar: calendar
        )
        let reset = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .resetToDay, dayStartSlotIndex: 0),
            vacations: [vacation],
            presets: allPresets,
            calendar: calendar
        )

        #expect(invert == ids[10])
        #expect(continued == ids[3])
        #expect(reset == ids[0])
    }

    @Test
    func testMultipleInvertVacationsAccumulateShiftAndPhase() {
        let ids = slotIDs
        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .invert),
            vacations: [
                vacation(date(2026, 7, 20), date(2026, 7, 24)),
                vacation(date(2026, 8, 13), date(2026, 8, 16)),
            ],
            presets: presets(ids: ids),
            calendar: calendar
        )

        #expect(result == ids[12])
    }

    @Test
    func testYearBoundaryVacationUsesCalendarDayDifference() {
        let ids = slotIDs
        let result = VacationAwareRotation.presetID(
            for: date(2027, 1, 4),
            pattern: pattern(ids: ids, policy: .invert),
            vacations: [vacation(date(2026, 12, 30), date(2027, 1, 3))],
            presets: presets(ids: ids),
            calendar: calendar
        )

        #expect(result == ids[9])
    }

    @Test
    func testVacationBeforeEffectiveStartDoesNotShiftRotation() {
        let ids = slotIDs
        let obon = vacation(date(2026, 8, 13), date(2026, 8, 16))
        let beforeStart = vacation(date(2026, 4, 20), date(2026, 4, 24))
        let baseline = pattern(ids: ids, policy: .invert)
        let allPresets = presets(ids: ids)

        let beforeOnly = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: baseline,
            vacations: [beforeStart],
            presets: allPresets,
            calendar: calendar
        )
        let withObon = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: baseline,
            vacations: [beforeStart, obon],
            presets: allPresets,
            calendar: calendar
        )

        #expect(beforeOnly == ids[7])
        #expect(withObon == ids[10])
    }

    @Test
    func testPresetOverrideUsesPreviousWorkingSlotSkippingNilRestDays() {
        let ids = slotIDs
        let slots: [UUID?] = [ids[0], ids[1], nil, ids[3]]
        let customPattern = RotationPatternSnapshot(
            id: UUID(),
            name: "nil-before-vacation",
            anchorDate: date(2026, 8, 10),
            cycleLength: 4,
            slots: slots,
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: true,
            crossVacationPolicy: .invert
        )

        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 16),
            pattern: customPattern,
            vacations: [vacation(date(2026, 8, 13), date(2026, 8, 15))],
            presets: presets(ids: ids, overrides: [1: .continue]),
            calendar: calendar
        )

        #expect(result == ids[3])
    }

    @Test
    func testAllRestSlotsDoNotScanBeyondOneCycleForPreviousWorkingSlot() {
        let pattern = RotationPatternSnapshot(
            id: UUID(),
            name: "all-rest",
            anchorDate: date(2020, 1, 1),
            cycleLength: 7,
            slots: Array(repeating: nil, count: 7),
            startDate: nil,
            endDate: nil,
            priority: 0,
            isActive: true,
            crossVacationPolicy: .resetToDay
        )

        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern,
            vacations: [vacation(date(2026, 8, 13), date(2026, 8, 16))],
            presets: [:],
            calendar: calendar
        )

        #expect(result == nil)
    }

    @Test
    func testVacationCrossingEffectiveStartDoesNotReadPreStartPresetOverride() {
        let ids = slotIDs
        let customPattern = RotationPatternSnapshot(
            id: UUID(),
            name: "start-clamped",
            anchorDate: date(2026, 8, 10),
            cycleLength: 14,
            slots: ids.map { Optional($0) },
            startDate: date(2026, 8, 13),
            endDate: nil,
            priority: 0,
            isActive: true,
            crossVacationPolicy: .invert
        )

        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 16),
            pattern: customPattern,
            vacations: [vacation(date(2026, 8, 10), date(2026, 8, 15))],
            presets: presets(ids: ids, overrides: [2: .continue]),
            calendar: calendar
        )

        #expect(result == ids[10])
    }

    @Test
    func testAdjacentVacationsCoalesceBeforeApplyingPolicy() {
        let ids = slotIDs
        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 21),
            pattern: pattern(ids: ids, policy: .invert),
            vacations: [
                vacation(date(2026, 8, 13), date(2026, 8, 16)),
                vacation(date(2026, 8, 17), date(2026, 8, 20)),
            ],
            presets: presets(ids: ids),
            calendar: calendar
        )

        #expect(result == ids[10])
    }

    @Test
    func testOddCycleInvertFallsBackToContinue() {
        let ids = Array(slotIDs.prefix(7))
        let result = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .invert, cycleLength: 7),
            vacations: [vacation(date(2026, 8, 13), date(2026, 8, 16))],
            presets: presets(ids: ids),
            calendar: calendar
        )

        #expect(result == ids[3])
    }

    @Test
    func testPresetOverrideWinsOverPatternPolicy() {
        let ids = slotIDs
        let vacation = vacation(date(2026, 8, 13), date(2026, 8, 16))

        let continued = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .invert),
            vacations: [vacation],
            presets: presets(ids: ids, overrides: [2: .continue]),
            calendar: calendar
        )
        let reset = VacationAwareRotation.presetID(
            for: date(2026, 8, 17),
            pattern: pattern(ids: ids, policy: .continue),
            vacations: [vacation],
            presets: presets(ids: ids, overrides: [2: .resetToDay]),
            calendar: calendar
        )

        #expect(continued == ids[3])
        #expect(reset == ids[0])
    }

    @Test
    func testVacationPeriodFactoryRejectsTooShortRange() {
        #expect(throws: VacationPeriodError.tooShort(days: 2)) {
            _ = try VacationPeriod.make(
                startDate: date(2026, 8, 13),
                endDate: date(2026, 8, 14),
                label: "Short",
                calendar: calendar
            )
        }
    }
}
