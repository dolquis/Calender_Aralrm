import SwiftUI

public struct AlarmDiagnosticsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL
    @State private var report: AlarmDiagnosticsReport?
    @State private var isRefreshing = false

    public init() {}

    public var body: some View {
        List {
            if let report {
                summarySection(report)
                checksSection(report)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("diagnostics.title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await runSchedulerRefresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("diagnostics.refresh_now")
                .disabled(isRefreshing)
            }
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func summarySection(_ report: AlarmDiagnosticsReport) -> some View {
        Section("diagnostics.summary") {
            HStack(spacing: 12) {
                Image(systemName: report.overallStatus.systemImage)
                    .foregroundStyle(report.overallStatus.tint)
                Text(LocalizedStringKey(report.overallStatus.titleKey))
                    .font(.headline)
                Spacer()
            }
            .accessibilityElement(children: .combine)

            if let next = report.nextAlarmSummary {
                LabeledContent(
                    "diagnostics.next_alarm",
                    value: next.fireDate.formatted(date: .abbreviated, time: .shortened)
                )
                LabeledContent("diagnostics.next_alarm_label", value: next.label)
            } else {
                LabeledContent(
                    "diagnostics.next_alarm",
                    value: String(localized: "diagnostics.none")
                )
            }

            LabeledContent("diagnostics.scheduled_count", value: "\(report.scheduledAlarmCount)")

            if let lastRun = report.lastSchedulerRunAt {
                LabeledContent(
                    "diagnostics.last_scheduler_run",
                    value: lastRun.formatted(date: .abbreviated, time: .shortened)
                )
            } else {
                LabeledContent(
                    "diagnostics.last_scheduler_run",
                    value: String(localized: "diagnostics.none")
                )
            }

            if let result = report.lastSchedulerResultRaw {
                LabeledContent("diagnostics.last_scheduler_result", value: result)
            }

            LabeledContent(
                "diagnostics.generated_at",
                value: report.generatedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }

    private func checksSection(_ report: AlarmDiagnosticsReport) -> some View {
        Section("diagnostics.checks") {
            ForEach(report.checks) { check in
                AlarmDiagnosticsCheckRow(check: check) { action in
                    Task { await perform(action) }
                }
            }
        }
    }

    private func perform(_ action: AlarmDiagnosticsRecoveryAction) async {
        switch action {
        case .requestAlarmAuthorization:
            _ = await dependencies.alarmAuthorization.request()
            await reload()
        case .refreshScheduledAlarms:
            await runSchedulerRefresh()
        case .openSettings:
            if let url = URL(string: "app-settings:") {
                openURL(url)
            }
        case .openHealthAuthorization:
            _ = await dependencies.sleepSampleWriter.requestAuthorization()
            await reload()
        case .none:
            break
        }
    }

    private func runSchedulerRefresh() async {
        isRefreshing = true
        await dependencies.alarmScheduler.refreshScheduledAlarms()
        await dependencies.liveActivityController.evaluate()
        await reload()
        isRefreshing = false
    }

    private func reload() async {
        report = await dependencies.alarmDiagnosticsService.generate()
    }
}

private struct AlarmDiagnosticsCheckRow: View {
    let check: AlarmDiagnosticsCheck
    let perform: (AlarmDiagnosticsRecoveryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            checkSummary
            if let action = check.recoveryAction, action != .none {
                Button {
                    perform(action)
                } label: {
                    Label(LocalizedStringKey(action.titleKey), systemImage: action.systemImage)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var checkSummary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: check.status.systemImage)
                .foregroundStyle(check.status.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(check.titleKey))
                    .font(.headline)
                Text(LocalizedStringKey(check.messageKey))
                    .foregroundStyle(.secondary)
                if let detail = check.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(LocalizedStringKey(check.status.shortKey))
                .font(.caption)
                .foregroundStyle(check.status.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

extension AlarmDiagnosticsStatus {
    fileprivate var titleKey: String {
        switch self {
        case .normal: "diagnostics.status.normal.title"
        case .warning: "diagnostics.status.warning.title"
        case .attention: "diagnostics.status.attention.title"
        case .critical: "diagnostics.status.critical.title"
        }
    }

    fileprivate var shortKey: String {
        switch self {
        case .normal: "diagnostics.status.normal"
        case .warning: "diagnostics.status.warning"
        case .attention: "diagnostics.status.attention"
        case .critical: "diagnostics.status.critical"
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .normal: "checkmark.seal.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    fileprivate var tint: Color {
        switch self {
        case .normal: .green
        case .warning: .yellow
        case .attention: .orange
        case .critical: .red
        }
    }
}

extension AlarmDiagnosticsRecoveryAction {
    fileprivate var titleKey: String {
        switch self {
        case .requestAlarmAuthorization: "diagnostics.action.request_permission"
        case .refreshScheduledAlarms: "diagnostics.action.refresh"
        case .openSettings: "diagnostics.action.open_settings"
        case .openHealthAuthorization: "diagnostics.action.healthkit"
        case .none: "diagnostics.action.none"
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .requestAlarmAuthorization: "bell.badge"
        case .refreshScheduledAlarms: "arrow.clockwise"
        case .openSettings: "gearshape"
        case .openHealthAuthorization: "heart"
        case .none: "checkmark"
        }
    }
}
