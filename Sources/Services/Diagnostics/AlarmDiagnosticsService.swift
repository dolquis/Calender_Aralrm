import Foundation
import SwiftData

#if canImport(HealthKit)
import HealthKit
#endif

public struct AlarmDiagnosticsReport: Equatable, Sendable {
    public var generatedAt: Date
    public var overallStatus: AlarmDiagnosticsStatus
    public var checks: [AlarmDiagnosticsCheck]
    public var nextAlarmSummary: NextAlarmSummary?
    public var scheduledAlarmCount: Int
    public var lastSchedulerRunAt: Date?
    public var lastSchedulerResultRaw: String?

    public init(
        generatedAt: Date,
        checks: [AlarmDiagnosticsCheck],
        nextAlarmSummary: NextAlarmSummary?,
        scheduledAlarmCount: Int,
        lastSchedulerRunAt: Date?,
        lastSchedulerResultRaw: String?
    ) {
        self.generatedAt = generatedAt
        self.overallStatus = Self.aggregate(checks.map(\.status))
        self.checks = checks
        self.nextAlarmSummary = nextAlarmSummary
        self.scheduledAlarmCount = scheduledAlarmCount
        self.lastSchedulerRunAt = lastSchedulerRunAt
        self.lastSchedulerResultRaw = lastSchedulerResultRaw
    }

    private static func aggregate(_ statuses: [AlarmDiagnosticsStatus]) -> AlarmDiagnosticsStatus {
        if statuses.contains(.critical) { return .critical }
        if statuses.contains(.attention) { return .attention }
        if statuses.contains(.warning) { return .warning }
        return .normal
    }
}

public struct NextAlarmSummary: Equatable, Sendable {
    public var fireDate: Date
    public var label: String
    public var alarmKitID: UUID?

    public init(fireDate: Date, label: String, alarmKitID: UUID?) {
        self.fireDate = fireDate
        self.label = label
        self.alarmKitID = alarmKitID
    }
}

public enum AlarmDiagnosticsStatus: String, Sendable, Equatable {
    case normal
    case warning
    case attention
    case critical
}

public struct AlarmDiagnosticsCheck: Identifiable, Equatable, Sendable {
    public var id: String
    public var titleKey: String
    public var messageKey: String
    public var detail: String?
    public var status: AlarmDiagnosticsStatus
    public var recoveryAction: AlarmDiagnosticsRecoveryAction?

    public init(
        id: String,
        titleKey: String,
        messageKey: String,
        detail: String? = nil,
        status: AlarmDiagnosticsStatus,
        recoveryAction: AlarmDiagnosticsRecoveryAction? = nil
    ) {
        self.id = id
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.detail = detail
        self.status = status
        self.recoveryAction = recoveryAction
    }
}

public enum AlarmDiagnosticsRecoveryAction: Equatable, Sendable {
    case requestAlarmAuthorization
    case refreshScheduledAlarms
    case openSettings
    case openHealthAuthorization
    case none
}

public enum AlarmDiagnosticsHealthKitState: Equatable, Sendable {
    case authorized
    case notAuthorized
    case unavailable
}

@MainActor
public final class AlarmDiagnosticsService {
    private let modelContainer: ModelContainer
    private let alarmClient: any AlarmSchedulingClient
    private let now: () -> Date
    private let calendar: Calendar
    private let appGroupAvailable: () -> Bool
    private let bgRefreshConfigured: () -> Bool
    private let healthKitState: () -> AlarmDiagnosticsHealthKitState

    public init(
        modelContainer: ModelContainer,
        alarmClient: any AlarmSchedulingClient,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        appGroupAvailable: @escaping () -> Bool = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedPersistence.appGroupID
            ) != nil
        },
        bgRefreshConfigured: @escaping () -> Bool = {
            !BGRefreshController.identifier.isEmpty
        },
        healthKitState: @escaping () -> AlarmDiagnosticsHealthKitState = {
            AlarmDiagnosticsService.currentHealthKitState()
        }
    ) {
        self.modelContainer = modelContainer
        self.alarmClient = alarmClient
        self.now = now
        self.calendar = calendar
        self.appGroupAvailable = appGroupAvailable
        self.bgRefreshConfigured = bgRefreshConfigured
        self.healthKitState = healthKitState
    }

    public func generate() async -> AlarmDiagnosticsReport {
        let generatedAt = now()
        let context = ModelContext(modelContainer)
        let settings = fetchSettings(in: context)
        let alarms = fetchAlarms(in: context)
        let liveIDs = (try? await alarmClient.scheduledIDs()) ?? []
        let nextAlarm = nextWakeAlarm(from: alarms, after: generatedAt)
        let expectedWakeDates = await expectedWakeDates(
            settings: settings,
            context: context,
            after: generatedAt
        )
        let authState = await alarmClient.authorizationState()

        let checks = [
            authorizationCheck(authState),
            nextAlarmCheck(nextAlarm, liveIDs: liveIDs),
            schedulerFreshnessCheck(settings, generatedAt: generatedAt),
            appGroupCheck(),
            bgRefreshCheck(),
            liveActivitySettingsCheck(settings),
            healthKitCheck(),
            upcomingUnsyncedDaysCheck(
                expectedWakeDates: expectedWakeDates,
                alarms: alarms,
                liveIDs: liveIDs
            ),
        ]

        return AlarmDiagnosticsReport(
            generatedAt: generatedAt,
            checks: checks,
            nextAlarmSummary: nextAlarm.map {
                NextAlarmSummary(
                    fireDate: $0.fireDate,
                    label: $0.label,
                    alarmKitID: $0.currentAlarmKitID
                )
            },
            scheduledAlarmCount: liveIDs.count,
            lastSchedulerRunAt: settings.lastAlarmSchedulerRunAt,
            lastSchedulerResultRaw: settings.lastAlarmSchedulerResultRaw
        )
    }

    private func fetchSettings(in context: ModelContext) -> AppSettings {
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return settings
        }
        let settings = AppSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }

    private func fetchAlarms(in context: ModelContext) -> [ShiftAlarm] {
        ((try? context.fetch(FetchDescriptor<ShiftAlarm>())) ?? [])
            .filter(\.isEnabled)
    }

    private func nextWakeAlarm(from alarms: [ShiftAlarm], after date: Date) -> ShiftAlarm? {
        alarms
            .filter { !$0.isBedtimeReminder && $0.fireDate > date }
            .sorted { $0.fireDate < $1.fireDate }
            .first
    }

    private func expectedWakeDates(
        settings: AppSettings,
        context: ModelContext,
        after date: Date
    ) async -> [Date] {
        let lookahead = max(1, settings.lookaheadDays)
        let days = Array(DayRange(start: date, dayCount: lookahead, calendar: calendar))
        let input = await AlarmScheduler.buildResolverInput(context: context, calendar: calendar)
        return days.compactMap { day in
            let resolved = DayResolver.resolve(date: day, input: input)
            guard !resolved.skipsAlarm,
                let fireTime = resolved.fireTime,
                let hour = fireTime.hour,
                let minute = fireTime.minute,
                let fireDate = day.combining(hour: hour, minute: minute, in: calendar),
                fireDate > date
            else { return nil }
            return fireDate
        }
    }

    private func authorizationCheck(
        _ state: AlarmAuthorizationState
    ) -> AlarmDiagnosticsCheck {
        switch state {
        case .authorized:
            return check(
                "authorization",
                message: "diagnostics.authorization.ok",
                status: .normal
            )
        case .notDetermined:
            return check(
                "authorization",
                message: "diagnostics.authorization.not_determined",
                status: .critical,
                recoveryAction: .requestAlarmAuthorization
            )
        case .denied:
            return check(
                "authorization",
                message: "diagnostics.authorization.denied",
                status: .critical,
                recoveryAction: .openSettings
            )
        }
    }

    private func nextAlarmCheck(
        _ alarm: ShiftAlarm?,
        liveIDs: Set<UUID>
    ) -> AlarmDiagnosticsCheck {
        guard let alarm else {
            return check(
                "next_alarm",
                message: "diagnostics.next_alarm.missing",
                status: .critical,
                recoveryAction: .refreshScheduledAlarms
            )
        }
        guard let savedID = alarm.currentAlarmKitID else {
            return check(
                "next_alarm",
                message: "diagnostics.next_alarm.unsaved",
                detail: alarm.label,
                status: .critical,
                recoveryAction: .refreshScheduledAlarms
            )
        }
        guard liveIDs.contains(savedID) else {
            return check(
                "next_alarm",
                message: "diagnostics.next_alarm.not_scheduled",
                detail: savedID.uuidString,
                status: .critical,
                recoveryAction: .refreshScheduledAlarms
            )
        }
        return check(
            "next_alarm",
            message: "diagnostics.next_alarm.ok",
            detail: alarm.label,
            status: .normal
        )
    }

    private func schedulerFreshnessCheck(
        _ settings: AppSettings,
        generatedAt: Date
    ) -> AlarmDiagnosticsCheck {
        guard let lastRun = settings.lastAlarmSchedulerRunAt else {
            return check(
                "last_sync",
                message: "diagnostics.last_sync.never",
                status: .attention,
                recoveryAction: .refreshScheduledAlarms
            )
        }
        let resultRaw = settings.lastAlarmSchedulerResultRaw
        let isFresh = generatedAt.timeIntervalSince(lastRun) <= 60 * 60 * 24
        let isCompleted = resultRaw == "completed"
        let isHealthy = isFresh && isCompleted
        let message =
            if isHealthy {
                "diagnostics.last_sync.ok"
            } else if isFresh {
                "diagnostics.last_sync.failed"
            } else {
                "diagnostics.last_sync.stale"
            }
        return check(
            "last_sync",
            message: message,
            detail: resultRaw,
            status: isHealthy ? .normal : .attention,
            recoveryAction: isHealthy ? nil : .refreshScheduledAlarms
        )
    }

    private func appGroupCheck() -> AlarmDiagnosticsCheck {
        let available = appGroupAvailable()
        return check(
            "app_group",
            message: available ? "diagnostics.app_group.ok" : "diagnostics.app_group.unavailable",
            status: available ? .normal : .attention,
            recoveryAction: available ? nil : .openSettings
        )
    }

    private func bgRefreshCheck() -> AlarmDiagnosticsCheck {
        let configured = bgRefreshConfigured()
        return check(
            "bg_refresh",
            message: configured ? "diagnostics.bg_refresh.ok" : "diagnostics.bg_refresh.missing",
            status: configured ? .normal : .attention,
            recoveryAction: configured ? nil : .refreshScheduledAlarms
        )
    }

    private func liveActivitySettingsCheck(_ settings: AppSettings) -> AlarmDiagnosticsCheck {
        let validLead = (1...24).contains(settings.liveActivityLeadHours)
        return check(
            "live_activity",
            message: validLead
                ? "diagnostics.live_activity.ok" : "diagnostics.live_activity.invalid",
            detail: "\(settings.liveActivityLeadHours)",
            status: validLead ? .normal : .warning,
            recoveryAction: validLead ? nil : .openSettings
        )
    }

    private func healthKitCheck() -> AlarmDiagnosticsCheck {
        switch healthKitState() {
        case .authorized:
            return check("healthkit", message: "diagnostics.healthkit.ok", status: .normal)
        case .notAuthorized:
            return check(
                "healthkit",
                message: "diagnostics.healthkit.not_authorized",
                status: .warning,
                recoveryAction: .openHealthAuthorization
            )
        case .unavailable:
            return check(
                "healthkit",
                message: "diagnostics.healthkit.unavailable",
                status: .normal
            )
        }
    }

    private func upcomingUnsyncedDaysCheck(
        expectedWakeDates: [Date],
        alarms: [ShiftAlarm],
        liveIDs: Set<UUID>
    ) -> AlarmDiagnosticsCheck {
        let alarmsByDay = Dictionary(
            grouping: alarms.filter { !$0.isBedtimeReminder },
            by: { calendar.startOfDay(for: $0.fireDate) }
        )
        let missingCount = expectedWakeDates.filter { fireDate in
            let day = calendar.startOfDay(for: fireDate)
            return !(alarmsByDay[day] ?? []).contains { alarm in
                guard let id = alarm.currentAlarmKitID else { return false }
                return liveIDs.contains(id)
            }
        }.count

        return check(
            "upcoming_days",
            message: missingCount == 0
                ? "diagnostics.upcoming_days.ok" : "diagnostics.upcoming_days.missing",
            detail: missingCount == 0 ? nil : "\(missingCount)",
            status: missingCount == 0 ? .normal : .attention,
            recoveryAction: missingCount == 0 ? nil : .refreshScheduledAlarms
        )
    }

    private func check(
        _ id: String,
        message: String,
        detail: String? = nil,
        status: AlarmDiagnosticsStatus,
        recoveryAction: AlarmDiagnosticsRecoveryAction? = nil
    ) -> AlarmDiagnosticsCheck {
        AlarmDiagnosticsCheck(
            id: id,
            titleKey: "diagnostics.check.\(id)",
            messageKey: message,
            detail: detail,
            status: status,
            recoveryAction: recoveryAction
        )
    }

    public static func currentHealthKitState() -> AlarmDiagnosticsHealthKitState {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable(),
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            return .unavailable
        }
        let store = HKHealthStore()
        return store.authorizationStatus(for: sleepType) == .sharingAuthorized
            ? .authorized : .notAuthorized
        #else
        return .unavailable
        #endif
    }
}
