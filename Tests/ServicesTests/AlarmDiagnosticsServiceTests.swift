import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
@Suite(.serialized)
struct AlarmDiagnosticsServiceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 18, hour: 8))!
    }

    @Test
    func testDIAGU1AlarmKitDeniedIsCritical() async throws {
        let report = await makeReport(authorizationState: .denied)

        #expect(report.overallStatus == .critical)
        #expect(try check("authorization", in: report).status == .critical)
        #expect(
            try check("authorization", in: report).recoveryAction == .openSettings
        )
    }

    @Test
    func testDIAGU2MissingNextAlarmIsCritical() async throws {
        let report = await makeReport(includeAlarm: false)

        #expect(report.overallStatus == .critical)
        #expect(try check("next_alarm", in: report).status == .critical)
    }

    @Test
    func testDIAGU3HealthKitOnlyUnauthorizedIsWarning() async throws {
        let report = await makeReport(healthKitState: .notAuthorized)

        #expect(report.overallStatus == .warning)
        #expect(try check("healthkit", in: report).status == .warning)
    }

    @Test
    func testDIAGU4StaleSchedulerRunIsAttention() async throws {
        let report = await makeReport(lastRun: now.addingTimeInterval(-25 * 60 * 60))

        #expect(report.overallStatus == .attention)
        #expect(try check("last_sync", in: report).status == .attention)
    }

    @Test
    func testDIAGU5AllChecksOkIsNormal() async throws {
        let report = await makeReport()

        #expect(report.overallStatus == .normal)
        #expect(report.nextAlarmSummary?.label == "Day")
        #expect(report.scheduledAlarmCount == 1)
        #expect(report.checks.allSatisfy { $0.status == .normal })
    }

    @Test
    func testDIAGU6SavedIDMissingFromAlarmKitIsCritical() async throws {
        let report = await makeReport(scheduledIDs: [])

        #expect(report.overallStatus == .critical)
        #expect(try check("next_alarm", in: report).status == .critical)
        #expect(
            try check("next_alarm", in: report).messageKey
                == "diagnostics.next_alarm.not_scheduled"
        )
    }

    private func makeReport(
        authorizationState: AlarmAuthorizationState = .authorized,
        scheduledIDs explicitScheduledIDs: Set<UUID>? = nil,
        includeAlarm: Bool = true,
        lastRun: Date? = nil,
        healthKitState: AlarmDiagnosticsHealthKitState = .authorized
    ) async -> AlarmDiagnosticsReport {
        let now = self.now
        let calendar = self.calendar
        let alarmID = UUID()
        let container = makeContainer(
            alarmID: alarmID,
            includeAlarm: includeAlarm,
            lastRun: lastRun ?? now.addingTimeInterval(-60 * 60)
        )
        let scheduledIDs = explicitScheduledIDs ?? (includeAlarm ? [alarmID] : [])
        let fake = FakeAlarmSchedulingClient(
            scheduledIDs: scheduledIDs,
            authorizationState: authorizationState
        )
        let service = AlarmDiagnosticsService(
            modelContainer: container,
            alarmClient: fake,
            now: { now },
            calendar: calendar,
            appGroupAvailable: { true },
            bgRefreshConfigured: { true },
            healthKitState: { healthKitState }
        )

        return await service.generate()
    }

    private func makeContainer(
        alarmID: UUID,
        includeAlarm: Bool,
        lastRun: Date
    ) -> ModelContainer {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(
            AppSettings(
                lookaheadDays: 2,
                liveActivityLeadHours: 8,
                lastAlarmSchedulerRunAt: lastRun,
                lastAlarmSchedulerResultRaw: "completed"
            )
        )
        let preset = ShiftPreset(
            name: "Day",
            colorHex: "#1E88E5",
            defaultAlarmHour: 9,
            defaultAlarmMinute: 0
        )
        context.insert(preset)
        context.insert(
            DayAssignment(
                date: calendar.startOfDay(for: now),
                preset: preset
            )
        )
        if includeAlarm {
            context.insert(
                ShiftAlarm(
                    fireDate: fireDate(hour: 9),
                    label: "Day",
                    alarmKitID: alarmID
                )
            )
        }
        try! context.save()
        return container
    }

    private func fireDate(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 18, hour: hour))!
    }

    private func check(
        _ id: String,
        in report: AlarmDiagnosticsReport
    ) throws -> AlarmDiagnosticsCheck {
        try #require(report.checks.first { $0.id == id })
    }
}
