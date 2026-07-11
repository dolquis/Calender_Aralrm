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

    // HOL-M3 (review): a real SchemaV5 *file* store migrates to SchemaV6 through the migration
    // plan, the new nullable columns start nil, backfill fills them, data and relationships
    // survive, and a second backfill run is a no-op. This exercises the same VersionedSchema +
    // migration plan + backfill call that `SharedPersistence.makeContainer` uses (its store URL
    // is fixed to the App Group, so the test writes to a temporary URL instead).
    @Test
    func v5FileStoreMigratesToV6AndBackfills() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "ShiftAlarmV6Migration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("ShiftAlarm.store")

        // Seed a SchemaV5 store. V5 reuses the SchemaV4 model classes for these entities, so
        // seed with the explicit versioned classes — never the live typealias, which now points
        // at SchemaV6 and would crash with a SwiftData cast error against a V5 container.
        do {
            let v5Schema = Schema(versionedSchema: SchemaV5.self)
            let v5Config = ModelConfiguration("MigrationTestV5", schema: v5Schema, url: storeURL)
            let v5Container = try ModelContainer(for: v5Schema, configurations: [v5Config])
            let v5Context = ModelContext(v5Container)
            let preset = SchemaV4.ShiftPreset(
                name: "Day", defaultAlarmHour: 6, defaultAlarmMinute: 0)
            v5Context.insert(preset)
            v5Context.insert(
                SchemaV4.HolidayOverride(
                    date: Date(timeIntervalSince1970: 86_400), kind: .publicHoliday,
                    label: "海の日", skipAlarm: true, replacementPreset: preset))
            v5Context.insert(SchemaV4.AppSettings(lookaheadDays: 42))
            try v5Context.save()
        }

        // Open the same store as SchemaV6 through the migration plan (lightweight V5 -> V6).
        let v6Schema = Schema(versionedSchema: SchemaV6.self)
        let v6Config = ModelConfiguration("MigrationTestV6", schema: v6Schema, url: storeURL)
        let v6Container = try ModelContainer(
            for: v6Schema, migrationPlan: ShiftAlarmMigrationPlan.self, configurations: [v6Config])

        // Migrated rows carry nil new columns, and fetching via the live typealias (= SchemaV6.*)
        // must succeed — this is exactly the cast that fatal-errored before, so it guards it.
        let preContext = ModelContext(v6Container)
        let preOverride = try #require(
            try preContext.fetch(FetchDescriptor<HolidayOverride>()).first)
        #expect(preOverride.alarmBehaviorRaw == nil)
        let preSettings = try #require(try preContext.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(preSettings.holidayAlarmDefaultRaw == nil)

        // Backfill via the same entry point `makeContainer` uses.
        HolidayBehaviorBackfill.run(container: v6Container)

        // Verify from a fresh context so we read persisted values.
        let verifyContext = ModelContext(v6Container)
        let override = try #require(
            try verifyContext.fetch(FetchDescriptor<HolidayOverride>()).first)
        #expect(override.alarmBehavior == .inherit)  // skipAlarm true -> inherit
        #expect(override.label == "海の日")  // data retained
        #expect(override.replacementPreset?.name == "Day")  // relationship retained
        let settings = try #require(try verifyContext.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(settings.holidayAlarmDefault == .silence)
        #expect(settings.lookaheadDays == 42)  // untouched column retained

        // Idempotent: a second backfill on the migrated store changes nothing.
        let second = HolidayBehaviorBackfill.run(in: ModelContext(v6Container))
        #expect(second == 0)
    }
}
