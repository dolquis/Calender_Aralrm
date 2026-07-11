import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
@Suite(.serialized)
struct SchemaV3ToV4MigrationTests {
    @Test
    func testV3StoreMigratesVacationDefaults() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "ShiftAlarmV4Migration-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("ShiftAlarm.store")

        do {
            let v3Schema = Schema(versionedSchema: SchemaV3.self)
            let v3Configuration = ModelConfiguration(
                "MigrationTestV3",
                schema: v3Schema,
                url: storeURL
            )
            let v3Container = try ModelContainer(for: v3Schema, configurations: [v3Configuration])
            let v3Context = ModelContext(v3Container)
            let preset = SchemaV3.ShiftPreset(
                name: "Day",
                defaultAlarmHour: 6,
                defaultAlarmMinute: 0
            )
            v3Context.insert(preset)
            v3Context.insert(
                SchemaV3.RotationPattern(
                    name: "rotation",
                    anchorDate: Date(timeIntervalSince1970: 0),
                    cycleLength: 1,
                    slots: [preset.id]
                ))
            v3Context.insert(
                SchemaV3.HolidayOverride(
                    date: Date(timeIntervalSince1970: 86_400),
                    kind: .publicHoliday,
                    label: "Holiday"
                ))
            try v3Context.save()
        }

        let v4Schema = Schema(versionedSchema: SchemaV4.self)
        let v4Configuration = ModelConfiguration(
            "MigrationTestV4",
            schema: v4Schema,
            url: storeURL
        )
        let v4Container = try ModelContainer(
            for: v4Schema,
            migrationPlan: ShiftAlarmMigrationPlan.self,
            configurations: [v4Configuration]
        )
        let v4Context = ModelContext(v4Container)
        let presets = try v4Context.fetch(FetchDescriptor<ShiftPreset>())
        let patterns = try v4Context.fetch(FetchDescriptor<RotationPattern>())
        // Fetch via the explicit V4 class: this container is pinned to SchemaV4, whereas the
        // live `HolidayOverride` typealias now points at SchemaV6 (P2-ζ). A version-pinned
        // migration test must assert against the version it opened.
        let overrides = try v4Context.fetch(FetchDescriptor<SchemaV4.HolidayOverride>())
        let vacations = try v4Context.fetch(FetchDescriptor<VacationPeriod>())

        #expect(presets.count == 1)
        #expect(presets.first?.crossVacationPolicy == nil)
        #expect(patterns.count == 1)
        #expect(patterns.first?.crossVacationPolicy == .invert)
        #expect(patterns.first?.dayStartSlotIndex == nil)
        #expect(overrides.count == 1)
        #expect(overrides.first?.isVacationGroup == false)
        #expect(vacations.isEmpty)
    }
}
