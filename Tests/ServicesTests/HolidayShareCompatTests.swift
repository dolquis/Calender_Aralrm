import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

/// P2-ζ (DEV-201) `.shiftalarm` backward/forward compatibility for holiday alarm behavior.
/// Test IDs HOL-S1/S2/S3 from `docs/p2-holiday-alarm-control.md` §12.
@MainActor
@Suite(.serialized)
struct HolidayShareCompatTests {
    private func bundle(overrides: [ShiftBundle.OverrideDTO]) -> ShiftBundle {
        ShiftBundle(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            presets: [],
            patterns: [],
            assignments: [],
            overrides: overrides
        )
    }

    private func fetchOverrides(_ container: ModelContainer) throws -> [Date: HolidayOverride] {
        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<HolidayOverride>())
        var out: [Date: HolidayOverride] = [:]
        for row in rows { out[Calendar.current.startOfDay(for: row.date)] = row }
        return out
    }

    private func day(_ d: Int) -> CalendarDay { CalendarDay(year: 2026, month: 7, day: d) }

    private func date(_ d: Int) -> Date {
        Calendar.current.startOfDay(
            for: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: d))!)
    }

    // HOL-S1: a legacy bundle (no `alarmBehavior`) maps skipAlarm true->silence, false->ring.
    // This is the import mapping — deliberately different from the local backfill's
    // true->inherit (verified in HolidayMigrationBackfillTests).
    @Test
    func legacyBundleMapsSkipAlarmToConcreteBehavior() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let legacy = bundle(overrides: [
            ShiftBundle.OverrideDTO(
                date: day(20), kind: .publicHoliday, label: "silent", skipAlarm: true,
                replacementPresetID: nil),
            ShiftBundle.OverrideDTO(
                date: day(21), kind: .publicHoliday, label: "ring", skipAlarm: false,
                replacementPresetID: nil),
        ])
        // Legacy bundles carry no `inherit`, so no warning is produced.
        #expect(
            !ShiftBundleValidator.validate(legacy).warnings.contains {
                $0.code == .holidayBehaviorInherit
            })

        try ShareImporter.apply(bundle: legacy, container: container)

        let rows = try fetchOverrides(container)
        #expect(rows[date(20)]?.alarmBehavior == .silence)
        #expect(rows[date(21)]?.alarmBehavior == .ring)
    }

    // HOL-S2: a new bundle round-trips ring/silence unchanged.
    @Test
    func newBundleRoundTripsRingAndSilence() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let modern = bundle(overrides: [
            ShiftBundle.OverrideDTO(
                date: day(20), kind: .publicHoliday, label: "ring", skipAlarm: false,
                replacementPresetID: nil, alarmBehavior: .ring),
            ShiftBundle.OverrideDTO(
                date: day(21), kind: .publicHoliday, label: "silence", skipAlarm: true,
                replacementPresetID: nil, alarmBehavior: .silence),
        ])

        try ShareImporter.apply(bundle: modern, container: container)

        let rows = try fetchOverrides(container)
        #expect(rows[date(20)]?.alarmBehavior == .ring)
        #expect(rows[date(21)]?.alarmBehavior == .silence)
    }

    // HOL-S3: a bundle carrying `inherit` (third-party/hand-edited) is concretized to
    // silence on import, and the validator surfaces a warning.
    @Test
    func inheritBundleIsConcretizedToSilenceWithWarning() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let inheritBundle = bundle(overrides: [
            ShiftBundle.OverrideDTO(
                date: day(20), kind: .publicHoliday, label: "inherit", skipAlarm: false,
                replacementPresetID: nil, alarmBehavior: .inherit)
        ])

        let validation = ShiftBundleValidator.validate(inheritBundle)
        #expect(validation.warnings.contains { $0.code == .holidayBehaviorInherit })
        #expect(validation.errors.isEmpty)

        try ShareImporter.apply(bundle: inheritBundle, container: container)

        let rows = try fetchOverrides(container)
        #expect(rows[date(20)]?.alarmBehavior == .silence)
    }

    // HOL-S4 (review): missing-preset severity follows the effective (import-resolved) behavior,
    // not the raw `skipAlarm`. A ringing override with a missing replacement is an error; a
    // silenced one is only a warning — even when `skipAlarm` contradicts `alarmBehavior`.
    @Test
    func missingPresetSeverityFollowsEffectiveBehavior() {
        let missing = UUID()
        // alarmBehavior ring, skipAlarm true (contradiction): effective = ring -> error.
        let ringBundle = bundle(overrides: [
            ShiftBundle.OverrideDTO(
                date: day(20), kind: .publicHoliday, label: "ring", skipAlarm: true,
                replacementPresetID: missing, alarmBehavior: .ring)
        ])
        let ringResult = ShiftBundleValidator.validate(ringBundle)
        #expect(ringResult.errors.contains { $0.code == .missingPresetReference })

        // alarmBehavior silence, skipAlarm false: effective = silence -> warning only.
        let silenceBundle = bundle(overrides: [
            ShiftBundle.OverrideDTO(
                date: day(21), kind: .publicHoliday, label: "silence", skipAlarm: false,
                replacementPresetID: missing, alarmBehavior: .silence)
        ])
        let silenceResult = ShiftBundleValidator.validate(silenceBundle)
        #expect(!silenceResult.errors.contains { $0.code == .missingPresetReference })
        #expect(silenceResult.warnings.contains { $0.code == .missingPresetReference })
    }
}
