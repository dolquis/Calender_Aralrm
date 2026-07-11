import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

/// P2-ζ (DEV-201) lazy backfill of the SchemaV6 holiday-alarm columns. Test IDs
/// HOL-M1/HOL-M2 from `docs/p2-holiday-alarm-control.md` §12.
@MainActor
@Suite(.serialized)
struct HolidayMigrationBackfillTests {
    /// A bare in-memory SchemaV6 container so rows start with the new columns still nil
    /// (mimicking rows just migrated from SchemaV5). `SharedPersistence.makeContainer`
    /// would auto-backfill, which is not what we want to exercise here.
    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func day(_ offset: TimeInterval) -> Date { Date(timeIntervalSince1970: offset) }

    // HOL-M1: skipAlarm=true -> inherit, skipAlarm=false -> ring.
    @Test
    func backfillMapsSkipAlarmToBehavior() throws {
        let context = try makeContext()
        let silent = HolidayOverride(
            date: day(0), kind: .publicHoliday, label: "A", skipAlarm: true)
        let ringing = HolidayOverride(
            date: day(86_400), kind: .publicHoliday, label: "B", skipAlarm: false)
        context.insert(silent)
        context.insert(ringing)
        #expect(silent.alarmBehaviorRaw == nil)
        #expect(ringing.alarmBehaviorRaw == nil)

        let changed = HolidayBehaviorBackfill.run(in: context)

        #expect(changed == 2)
        #expect(silent.alarmBehavior == .inherit)
        #expect(ringing.alarmBehavior == .ring)
    }

    // HOL-M2: an AppSettings row with no default is backfilled to silence.
    @Test
    func backfillSeedsSilenceDefault() throws {
        let context = try makeContext()
        let settings = AppSettings()
        context.insert(settings)
        #expect(settings.holidayAlarmDefaultRaw == nil)

        HolidayBehaviorBackfill.run(in: context)

        #expect(settings.holidayAlarmDefault == .silence)
        #expect(settings.effectiveHolidayAlarmDefault == .silence)
    }

    // Backfill is idempotent: a second run changes nothing.
    @Test
    func backfillIsIdempotent() throws {
        let context = try makeContext()
        context.insert(
            HolidayOverride(date: day(0), kind: .publicHoliday, label: "A", skipAlarm: true))
        context.insert(AppSettings())

        let first = HolidayBehaviorBackfill.run(in: context)
        let second = HolidayBehaviorBackfill.run(in: context)

        #expect(first == 2)
        #expect(second == 0)
    }

    // A user's explicit skip should not be overwritten when it was already migrated.
    @Test
    func backfillDoesNotOverwriteExistingBehavior() throws {
        let context = try makeContext()
        let row = HolidayOverride(
            date: day(0), kind: .publicHoliday, label: "A", skipAlarm: true,
            alarmBehaviorRaw: HolidayAlarmBehavior.ring.rawValue)
        context.insert(row)

        let changed = HolidayBehaviorBackfill.run(in: context)

        #expect(changed == 0)
        #expect(row.alarmBehavior == .ring)
    }
}
