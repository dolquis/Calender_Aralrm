import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
@Suite(.serialized)
struct SchemaV4ToV5MigrationTests {
    @Test
    func testV4StoreMigratesAndStartsWithNoSwapRecords() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "ShiftAlarmV5Migration-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("ShiftAlarm.store")

        do {
            let v4Schema = Schema(versionedSchema: SchemaV4.self)
            let v4Configuration = ModelConfiguration(
                "MigrationTestV4",
                schema: v4Schema,
                url: storeURL
            )
            let v4Container = try ModelContainer(for: v4Schema, configurations: [v4Configuration])
            let v4Context = ModelContext(v4Container)
            let preset = SchemaV4.ShiftPreset(
                name: "Day",
                defaultAlarmHour: 6,
                defaultAlarmMinute: 0
            )
            v4Context.insert(preset)
            v4Context.insert(
                SchemaV4.DayAssignment(
                    date: Date(timeIntervalSince1970: 0),
                    preset: preset,
                    note: "manual"
                ))
            let vacation = try SchemaV4.VacationPeriod.make(
                startDate: Date(timeIntervalSince1970: 86_400),
                endDate: Date(timeIntervalSince1970: 86_400 * 3),
                label: "Break"
            )
            v4Context.insert(vacation)
            try v4Context.save()
        }

        let v5Schema = Schema(versionedSchema: SchemaV5.self)
        let v5Configuration = ModelConfiguration(
            "MigrationTestV5",
            schema: v5Schema,
            url: storeURL
        )
        let v5Container = try ModelContainer(
            for: v5Schema,
            migrationPlan: ShiftAlarmMigrationPlan.self,
            configurations: [v5Configuration]
        )
        let v5Context = ModelContext(v5Container)
        let presets = try v5Context.fetch(FetchDescriptor<ShiftPreset>())
        let assignments = try v5Context.fetch(FetchDescriptor<DayAssignment>())
        let vacations = try v5Context.fetch(FetchDescriptor<VacationPeriod>())
        let swapRecords = try v5Context.fetch(FetchDescriptor<SwapRecord>())

        #expect(presets.count == 1)
        #expect(assignments.count == 1)
        #expect(assignments.first?.note == "manual")
        #expect(vacations.count == 1)
        #expect(swapRecords.isEmpty)
    }
}
