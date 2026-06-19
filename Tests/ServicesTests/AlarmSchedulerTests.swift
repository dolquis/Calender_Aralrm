import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
@Suite(.serialized)
struct AlarmSchedulerTests {
    private enum SaveFailure: Error {
        case failed
    }

    private enum FetchFailure: Error {
        case failed
    }

    private var calendar: Calendar { Calendar.current }

    @Test
    func testResolverInputCapturesAllSources() async throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar.current

        let preset = ShiftPreset(
            name: "Night", colorHex: "#1E88E5", defaultAlarmHour: 20, defaultAlarmMinute: 0)
        context.insert(preset)

        let day = calendar.startOfDay(for: .now)
        let assignment = DayAssignment(date: day, preset: preset)
        context.insert(assignment)

        let holiday = HolidayOverride(
            date: calendar.date(byAdding: .day, value: 1, to: day)!,
            kind: .publicHoliday,
            label: "Holiday",
            skipAlarm: true
        )
        context.insert(holiday)

        let rotation = RotationPattern(
            name: "r",
            anchorDate: day,
            cycleLength: 1,
            slots: [preset.id]
        )
        context.insert(rotation)
        try context.save()

        let input = await AlarmScheduler.buildResolverInput(context: context, calendar: calendar)
        #expect(input.presets.count == 1)
        #expect(input.manualAssignments.count == 1)
        #expect(input.holidays.count == 1)
        #expect(input.rotations.count == 1)
        #expect((input.rotations.first?.slots.first ?? nil) == preset.id)
    }

    @Test
    func testASU1NewAlarmSchedulesOnly() async throws {
        let container = seededWakeContainer(hour: 8)
        let fake = FakeAlarmSchedulingClient()
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        #expect(scheduleCalls(in: operations).count == 1)
        #expect(cancelIDs(in: operations).isEmpty)
        let alarms = try fetchAlarms(in: container)
        #expect(alarms.count == 1)
        #expect(alarms.first?.currentAlarmKitID != nil)
        #expect(alarms.first?.pendingCancelIDs.isEmpty == true)
    }

    @Test
    func testASU2NoChangeDoesNotScheduleOrCancel() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8)
        try seedExistingAlarm(container: container, hour: 8, alarmKitID: oldID)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID])
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        #expect(scheduleCalls(in: operations).isEmpty)
        #expect(cancelIDs(in: operations).isEmpty)
        let alarms = try fetchAlarms(in: container)
        #expect(alarms.first?.currentAlarmKitID == oldID)
    }

    @Test
    func testASU3TimeChangeSavesPendingBeforeCancelingOldID() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8)
        try seedExistingAlarm(container: container, hour: 7, alarmKitID: oldID)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID])
        var saveSnapshots: [[UUID]] = []
        let scheduler = AlarmScheduler(
            modelContainer: container,
            alarmClient: fake,
            saveContext: { context in
                let alarms = (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
                saveSnapshots.append(alarms.flatMap(\.pendingCancelIDs))
                try context.save()
            }
        )

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        #expect(scheduleCalls(in: operations).count == 1)
        #expect(cancelIDs(in: operations) == [oldID])
        #expect(saveSnapshots.contains([oldID]))
        let alarms = try fetchAlarms(in: container)
        #expect(alarms.first?.currentAlarmKitID != oldID)
        #expect(alarms.first?.pendingCancelIDs.isEmpty == true)
    }

    @Test
    func testASU4ScheduleFailureKeepsOldAlarmAndRow() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8)
        try seedExistingAlarm(container: container, hour: 7, alarmKitID: oldID)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID], shouldFailSchedule: true)
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        #expect(scheduleCalls(in: operations).count == 1)
        #expect(cancelIDs(in: operations).isEmpty)
        let alarms = try fetchAlarms(in: container)
        #expect(alarms.first?.currentAlarmKitID == oldID)
        #expect(calendar.component(.hour, from: alarms.first!.fireDate) == 7)
    }

    @Test
    func testASU5CancelFailureLeavesPendingForNextRefresh() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8)
        try seedExistingAlarm(container: container, hour: 7, alarmKitID: oldID)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID], cancelFailures: [oldID])
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        var alarms = try fetchAlarms(in: container)
        #expect(alarms.first?.currentAlarmKitID != oldID)
        #expect(alarms.first?.pendingCancelIDs == [oldID])
        #expect(
            try fetchSettings(in: container).lastAlarmSchedulerResultRaw == "alarmOperationsFailed")

        await fake.setCancelFailures([])
        await scheduler.refreshScheduledAlarms()

        alarms = try fetchAlarms(in: container)
        #expect(alarms.first?.pendingCancelIDs.isEmpty == true)
        #expect(try fetchSettings(in: container).lastAlarmSchedulerResultRaw == "completed")
        let operations = await fake.recordedOperations()
        #expect(cancelIDs(in: operations).filter { $0 == oldID }.count == 2)
    }

    @Test
    func testASU6BedtimeAndWakeOnSameCalendarDayDoNotCollide() async throws {
        let container = seededWakeContainer(
            hour: 23,
            targetSleepDuration: 60 * 60,
            bedtimeLeadMinutes: 30
        )
        let fake = FakeAlarmSchedulingClient()
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        let alarms = try fetchAlarms(in: container)
        #expect(alarms.count == 2)
        #expect(alarms.filter(\.isBedtimeReminder).count == 1)
        #expect(alarms.filter { !$0.isBedtimeReminder }.count == 1)
        let operations = await fake.recordedOperations()
        let kinds = scheduleCalls(in: operations).map(\.kind)
        #expect(kinds.contains(.main))
        #expect(kinds.contains(.bedtime))
    }

    @Test
    func testASU7SkipAlarmCancelsThroughPendingPath() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8, skipAlarm: true)
        try seedExistingAlarm(container: container, hour: 8, alarmKitID: oldID)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID])
        var saveSnapshots: [[UUID]] = []
        let scheduler = AlarmScheduler(
            modelContainer: container,
            alarmClient: fake,
            saveContext: { context in
                let alarms = (try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? []
                saveSnapshots.append(alarms.flatMap(\.pendingCancelIDs))
                try context.save()
            }
        )

        await scheduler.refreshScheduledAlarms()

        #expect(saveSnapshots.contains([oldID]))
        #expect(cancelIDs(in: await fake.recordedOperations()) == [oldID])
        #expect(try fetchAlarms(in: container).isEmpty)
    }

    @Test
    func testASU8HolidayOverrideExcludesExpectedAlarmAndCancelsPendingFirst() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8, useRotation: true, holidaySkip: true)
        try seedExistingAlarm(container: container, hour: 8, alarmKitID: oldID)
        let inputContext = ModelContext(container)
        let input = await AlarmScheduler.buildResolverInput(
            context: inputContext,
            calendar: calendar
        )
        #expect(DayResolver.resolve(date: day(offset: 1), input: input).skipsAlarm)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID])
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        #expect(scheduleCalls(in: operations).isEmpty)
        #expect(cancelIDs(in: operations) == [oldID])
        #expect(try fetchAlarms(in: container).isEmpty)
    }

    @Test
    func testASU9SaveFailureRollsBackNewScheduledID() async throws {
        let container = seededWakeContainer(hour: 8)
        let fake = FakeAlarmSchedulingClient()
        var shouldFailSave = true
        let scheduler = AlarmScheduler(
            modelContainer: container,
            alarmClient: fake,
            saveContext: { context in
                if shouldFailSave {
                    shouldFailSave = false
                    throw SaveFailure.failed
                }
                try context.save()
            }
        )

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        let schedules = scheduleCalls(in: operations)
        #expect(schedules.count == 1)
        #expect(cancelIDs(in: operations) == schedules.map(\.id))
        #expect(try fetchAlarms(in: container).isEmpty)
    }

    @Test
    func testASU9RollbackCancelFailureIsRecoveredAsOrphan() async throws {
        let container = seededWakeContainer(hour: 8)
        let fake = FakeAlarmSchedulingClient(shouldFailCancel: true)
        var shouldFailSave = true
        let scheduler = AlarmScheduler(
            modelContainer: container,
            alarmClient: fake,
            saveContext: { context in
                if shouldFailSave {
                    shouldFailSave = false
                    throw SaveFailure.failed
                }
                try context.save()
            }
        )

        await scheduler.refreshScheduledAlarms()

        let orphanID = try #require(await fake.scheduledIDSet().first)
        #expect(try fetchAlarms(in: container).isEmpty)

        await fake.setShouldFailCancel(false)
        await scheduler.refreshScheduledAlarms()

        let liveIDs = await fake.scheduledIDSet()
        let operations = await fake.recordedOperations()
        #expect(cancelIDs(in: operations).filter { $0 == orphanID }.count == 2)
        #expect(!liveIDs.contains(orphanID))
        #expect(liveIDs.count == 1)
        #expect(try fetchAlarms(in: container).count == 1)
    }

    @Test
    func testASU10FetchFailureSkipsOrphanSweepAndDiffSync() async throws {
        let liveID = UUID()
        let container = seededWakeContainer(hour: 8)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [liveID])
        let scheduler = AlarmScheduler(
            modelContainer: container,
            alarmClient: fake,
            fetchExistingAlarms: { _ in throw FetchFailure.failed }
        )

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        let liveIDs = await fake.scheduledIDSet()
        #expect(operations.isEmpty)
        #expect(liveIDs == Set([liveID]))
    }

    @Test
    func testASI1RefreshOperationSequenceUsesFakeClient() async throws {
        let oldID = UUID()
        let container = seededWakeContainer(hour: 8)
        try seedExistingAlarm(container: container, hour: 7, alarmKitID: oldID)
        let fake = FakeAlarmSchedulingClient(scheduledIDs: [oldID])
        let scheduler = AlarmScheduler(modelContainer: container, alarmClient: fake)

        await scheduler.refreshScheduledAlarms()

        let operations = await fake.recordedOperations()
        guard case .scheduledIDs = operations.first else {
            Issue.record("refresh should inspect live AlarmKit IDs before diff-sync")
            return
        }
        #expect(scheduleCalls(in: operations).count == 1)
        #expect(cancelIDs(in: operations) == [oldID])
    }

    @Test
    func testASM1PreP04V1StoreMigratesAlarmKitIDAndPendingDefaults() throws {
        let alarmKitID = UUID(uuidString: "00000000-0000-0000-0000-00000000A141")!
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "ShiftAlarmMigration-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let storeURL = try copyPreP04V1StoreFixture(to: directory)

        let newSchema = Schema(versionedSchema: SchemaV3.self)
        let newConfiguration = ModelConfiguration(
            "MigrationTest",
            schema: newSchema,
            url: storeURL
        )
        let newContainer = try ModelContainer(
            for: newSchema,
            migrationPlan: ShiftAlarmMigrationPlan.self,
            configurations: [newConfiguration]
        )
        let newContext = ModelContext(newContainer)
        let alarms = try newContext.fetch(FetchDescriptor<ShiftAlarm>())

        #expect(alarms.count == 1)
        #expect(alarms.first?.label == "Legacy alarm")
        #expect(alarms.first?.currentAlarmKitID == alarmKitID)
        #expect(alarms.first?.alarmKitID == alarmKitID)
        #expect(alarms.first?.pendingCancelIDs.isEmpty == true)
    }

    @Test
    func testASM2V2StoreMigratesDiagnosticsSettingsDefaults() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "ShiftAlarmV3Migration-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("ShiftAlarm.store")

        do {
            let v2Schema = Schema(versionedSchema: SchemaV2.self)
            let v2Configuration = ModelConfiguration(
                "MigrationTestV2",
                schema: v2Schema,
                url: storeURL
            )
            let v2Container = try ModelContainer(for: v2Schema, configurations: [v2Configuration])
            let v2Context = ModelContext(v2Container)
            v2Context.insert(SchemaV2.AppSettings(lookaheadDays: 5))
            try v2Context.save()
        }

        let v3Schema = Schema(versionedSchema: SchemaV3.self)
        let v3Configuration = ModelConfiguration(
            "MigrationTestV3",
            schema: v3Schema,
            url: storeURL
        )
        let v3Container = try ModelContainer(
            for: v3Schema,
            migrationPlan: ShiftAlarmMigrationPlan.self,
            configurations: [v3Configuration]
        )
        let v3Context = ModelContext(v3Container)
        let settings = try #require(try v3Context.fetch(FetchDescriptor<AppSettings>()).first)

        #expect(settings.lookaheadDays == 5)
        #expect(settings.lastAlarmSchedulerRunAt == nil)
        #expect(settings.lastAlarmSchedulerResultRaw == nil)
    }

    private func seededWakeContainer(
        hour: Int,
        minute: Int = 0,
        targetSleepDuration: Double = 8 * 3600,
        bedtimeLeadMinutes: Int = 0,
        skipAlarm: Bool = false,
        useRotation: Bool = false,
        holidaySkip: Bool = false
    ) -> ModelContainer {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(AppSettings(lookaheadDays: 5))
        let preset = ShiftPreset(
            name: "Day",
            colorHex: "#1E88E5",
            defaultAlarmHour: hour,
            defaultAlarmMinute: minute,
            targetSleepDuration: targetSleepDuration,
            bedtimeLeadMinutes: bedtimeLeadMinutes
        )
        context.insert(preset)
        if useRotation {
            context.insert(
                RotationPattern(
                    name: "r",
                    anchorDate: day(offset: 1),
                    cycleLength: 1,
                    slots: [preset.id],
                    startDate: day(offset: 1),
                    endDate: day(offset: 1)
                ))
        } else {
            context.insert(
                DayAssignment(
                    date: day(offset: 1),
                    preset: skipAlarm ? nil : preset,
                    skipAlarm: skipAlarm
                ))
        }
        if holidaySkip {
            context.insert(
                HolidayOverride(
                    date: day(offset: 1),
                    kind: .publicHoliday,
                    label: "Holiday",
                    skipAlarm: true
                ))
        }
        try! context.save()
        return container
    }

    private func seedExistingAlarm(
        container: ModelContainer,
        hour: Int,
        minute: Int = 0,
        alarmKitID: UUID,
        isBedtimeReminder: Bool = false
    ) throws {
        let context = ModelContext(container)
        context.insert(
            ShiftAlarm(
                fireDate: fireDate(offset: 1, hour: hour, minute: minute),
                label: "Day",
                soundID: AlarmSound.systemDefault.id,
                alarmKitID: alarmKitID,
                isBedtimeReminder: isBedtimeReminder
            ))
        try context.save()
    }

    private func fetchAlarms(in container: ModelContainer) throws -> [ShiftAlarm] {
        let context = ModelContext(container)
        let alarms = try context.fetch(FetchDescriptor<ShiftAlarm>())
        return alarms.sorted { $0.fireDate < $1.fireDate }
    }

    private func fetchSettings(in container: ModelContainer) throws -> AppSettings {
        let context = ModelContext(container)
        return try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
    }

    private func copyPreP04V1StoreFixture(to directory: URL) throws -> URL {
        let fixtureDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Support/Fixtures/PreP04V1Store", directoryHint: .isDirectory)
        for fileName in [
            SharedPersistence.storeFileName,
            "\(SharedPersistence.storeFileName)-shm",
            "\(SharedPersistence.storeFileName)-wal",
        ] {
            try FileManager.default.copyItem(
                at: fixtureDirectory.appending(path: fileName),
                to: directory.appendingPathComponent(fileName)
            )
        }
        return directory.appendingPathComponent(SharedPersistence.storeFileName)
    }

    private func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    private func fireDate(offset: Int, hour: Int, minute: Int) -> Date {
        day(offset: offset).combining(hour: hour, minute: minute, in: calendar)!
    }

    private func scheduleCalls(
        in operations: [FakeAlarmSchedulingClient.Operation]
    ) -> [FakeAlarmSchedulingClient.ScheduleCall] {
        operations.compactMap { operation in
            if case .schedule(let call) = operation {
                return call
            }
            return nil
        }
    }

    private func cancelIDs(in operations: [FakeAlarmSchedulingClient.Operation]) -> [UUID] {
        operations.compactMap { operation in
            if case .cancel(let id) = operation {
                return id
            }
            return nil
        }
    }
}
