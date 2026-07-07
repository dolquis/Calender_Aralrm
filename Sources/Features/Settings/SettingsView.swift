import SwiftData
import SwiftUI

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query private var settingsList: [AppSettings]
    @State private var diagnosticsStatus: AlarmDiagnosticsStatus?

    public init() {}

    public var body: some View {
        Group {
            if let settings = settingsList.first {
                form(for: settings)
            } else {
                ProgressView()
                    .task { dependencies.ensureSettingsSingleton() }
            }
        }
        .navigationTitle("tab.settings")
        .task {
            await dependencies.alarmAuthorization.refresh()
            diagnosticsStatus =
                await dependencies.alarmDiagnosticsService.generate().overallStatus
        }
    }

    @ViewBuilder
    private func form(for s: AppSettings) -> some View {
        Form {
            Section("settings.permission_section") {
                PermissionStatusView()
            }
            Section("settings.alarm_section") {
                Stepper(
                    value: Binding(
                        get: { s.lookaheadDays },
                        set: { newValue in
                            s.lookaheadDays = newValue
                            try? modelContext.save()
                            Task {
                                await dependencies.alarmScheduler.refreshScheduledAlarms()
                                await dependencies.liveActivityController.evaluate()
                            }
                        }
                    ), in: 7...90
                ) {
                    LabeledContent("settings.lookahead_days", value: "\(s.lookaheadDays)")
                }
                Stepper(
                    value: Binding(
                        get: { s.liveActivityLeadHours },
                        set: { newValue in
                            s.liveActivityLeadHours = newValue
                            try? modelContext.save()
                            Task { await dependencies.liveActivityController.evaluate() }
                        }
                    ), in: 1...24
                ) {
                    LabeledContent(
                        "settings.live_activity_lead_hours", value: "\(s.liveActivityLeadHours)")
                }
                Picker(
                    "settings.default_sound",
                    selection: Binding(
                        get: { s.defaultSoundID },
                        set: { newValue in
                            s.defaultSoundID = newValue
                            try? modelContext.save()
                            Task {
                                await dependencies.alarmScheduler.refreshScheduledAlarms()
                                await dependencies.liveActivityController.evaluate()
                            }
                        }
                    )
                ) {
                    ForEach(AlarmSound.allBuiltIn) { sound in
                        Text(LocalizedStringKey(sound.displayNameKey)).tag(sound.id)
                    }
                }
            }
            Section("settings.safety_diagnostics_section") {
                NavigationLink {
                    AlarmDiagnosticsView()
                } label: {
                    HStack {
                        Label("diagnostics.title", systemImage: "stethoscope")
                        Spacer()
                        if let diagnosticsStatus {
                            StatusPill(
                                LocalizedStringKey(diagnosticsStatus.pillKey),
                                tint: diagnosticsStatus.pillTint
                            )
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    HolidayManagerView()
                } label: {
                    Label("settings.holidays", systemImage: "calendar.badge.exclamationmark")
                }
                NavigationLink {
                    ExportView()
                } label: {
                    Label("settings.export", systemImage: "square.and.arrow.up")
                }
                NavigationLink {
                    ICSExportView()
                } label: {
                    Label("ics.export.nav_title", systemImage: "calendar.badge.plus")
                }
                NavigationLink {
                    ImportView()
                } label: {
                    Label("settings.import", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("settings.data_section")
            } footer: {
                Text("settings.data_footer")
            }
            Section("settings.about") {
                LabeledContent("settings.version", value: appVersionString())
            }
        }
    }

    private func appVersionString() -> String {
        let v =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

extension AlarmDiagnosticsStatus {
    fileprivate var pillKey: String {
        switch self {
        case .normal: "diagnostics.status.normal"
        case .warning: "diagnostics.status.warning"
        case .attention: "diagnostics.status.attention"
        case .critical: "diagnostics.status.critical"
        }
    }

    fileprivate var pillTint: Color {
        switch self {
        case .normal: .green
        case .warning: .orange
        case .attention: .orange
        case .critical: .red
        }
    }
}
