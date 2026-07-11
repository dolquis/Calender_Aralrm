import Foundation
import Testing

@testable import ShiftAlarm

/// P2-ζ (DEV-201) holiday alarm behavior resolution. Test IDs HOL-U1..U6 from
/// `docs/p2-holiday-alarm-control.md` §12.
struct HolidayAlarmResolveTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func preset(_ id: UUID, hour: Int) -> ShiftPresetSnapshot {
        ShiftPresetSnapshot(
            id: id, name: "P", colorHex: "#000",
            alarmTime: DateComponents(hour: hour, minute: 0),
            soundID: "system.default"
        )
    }

    private func input(
        day: Date,
        holiday: HolidayOverrideSnapshot,
        globalDefault: HolidayAlarmBehavior,
        presets: [UUID: ShiftPresetSnapshot] = [:],
        rotations: [RotationPatternSnapshot] = []
    ) -> DayResolverInput {
        DayResolverInput(
            manualAssignments: [:],
            holidays: [calendar.startOfDay(for: day): holiday],
            rotations: rotations,
            presets: presets,
            holidayAlarmDefault: globalDefault,
            calendar: calendar
        )
    }

    // HOL-U1: inherit + global silence => does not ring (post-migration = current behavior).
    @Test
    func inheritWithGlobalSilenceDoesNotRing() {
        let day = date(2026, 7, 20)
        let holiday = HolidayOverrideSnapshot(
            label: "海の日", skipAlarm: true, replacementPresetID: nil, behavior: .inherit)
        let resolved = DayResolver.resolve(
            date: day, input: input(day: day, holiday: holiday, globalDefault: .silence))
        #expect(resolved.skipsAlarm)
        #expect(resolved.fireTime == nil)
    }

    // HOL-U2: inherit + global ring => rings (one-switch for people who work holidays).
    @Test
    func inheritWithGlobalRingFallsThroughToRotation() {
        let day = date(2026, 7, 20)
        let rotationPreset = UUID()
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "R", anchorDate: date(2026, 7, 20), cycleLength: 1,
            slots: [rotationPreset], startDate: nil, endDate: nil, priority: 0, isActive: true)
        let holiday = HolidayOverrideSnapshot(
            label: "海の日", skipAlarm: true, replacementPresetID: nil, behavior: .inherit)
        let resolved = DayResolver.resolve(
            date: day,
            input: input(
                day: day, holiday: holiday, globalDefault: .ring,
                presets: [rotationPreset: preset(rotationPreset, hour: 6)], rotations: [rotation]))
        #expect(!resolved.skipsAlarm)
        #expect(resolved.presetID == rotationPreset)
        #expect(resolved.fireTime == DateComponents(hour: 6, minute: 0))
    }

    // HOL-U3: per-row silence stays silent even when the global default is ring.
    @Test
    func rowSilenceOverridesGlobalRing() {
        let day = date(2026, 7, 20)
        let holiday = HolidayOverrideSnapshot(
            label: "海の日", skipAlarm: true, replacementPresetID: nil, behavior: .silence)
        let resolved = DayResolver.resolve(
            date: day, input: input(day: day, holiday: holiday, globalDefault: .ring))
        #expect(resolved.skipsAlarm)
    }

    // HOL-U4: per-row ring + replacement preset fires at the replacement time.
    @Test
    func rowRingWithReplacementUsesReplacementTime() {
        let day = date(2026, 7, 20)
        let replacementID = UUID()
        let holiday = HolidayOverrideSnapshot(
            label: "海の日", skipAlarm: false, replacementPresetID: replacementID, behavior: .ring)
        let resolved = DayResolver.resolve(
            date: day,
            input: input(
                day: day, holiday: holiday, globalDefault: .silence,
                presets: [replacementID: preset(replacementID, hour: 10)]))
        #expect(!resolved.skipsAlarm)
        #expect(resolved.presetID == replacementID)
        #expect(resolved.fireTime == DateComponents(hour: 10, minute: 0))
    }

    // HOL-U5: per-row ring without a replacement falls through to rotation resolution.
    @Test
    func rowRingWithoutReplacementFallsThroughToRotation() {
        let day = date(2026, 7, 20)
        let rotationPreset = UUID()
        let rotation = RotationPatternSnapshot(
            id: UUID(), name: "R", anchorDate: date(2026, 7, 20), cycleLength: 1,
            slots: [rotationPreset], startDate: nil, endDate: nil, priority: 0, isActive: true)
        let holiday = HolidayOverrideSnapshot(
            label: "海の日", skipAlarm: false, replacementPresetID: nil, behavior: .ring)
        let resolved = DayResolver.resolve(
            date: day,
            input: input(
                day: day, holiday: holiday, globalDefault: .silence,
                presets: [rotationPreset: preset(rotationPreset, hour: 7)], rotations: [rotation]))
        #expect(resolved.presetID == rotationPreset)
        #expect(resolved.fireTime == DateComponents(hour: 7, minute: 0))
    }

    // HOL-U6: a manual assignment still wins over the holiday branch (unchanged precedence).
    @Test
    func manualAssignmentTakesPrecedenceOverHoliday() {
        let day = date(2026, 7, 20)
        let manualID = UUID()
        let holiday = HolidayOverrideSnapshot(
            label: "海の日", skipAlarm: true, replacementPresetID: nil, behavior: .silence)
        let resolved = DayResolver.resolve(
            date: day,
            input: DayResolverInput(
                manualAssignments: [
                    calendar.startOfDay(for: day): DayAssignmentSnapshot(
                        presetID: manualID, overrideTime: nil, skipAlarm: false, note: "")
                ],
                holidays: [calendar.startOfDay(for: day): holiday],
                rotations: [],
                presets: [manualID: preset(manualID, hour: 9)],
                holidayAlarmDefault: .ring,
                calendar: calendar))
        #expect(resolved.presetID == manualID)
        #expect(resolved.fireTime == DateComponents(hour: 9, minute: 0))
    }
}
