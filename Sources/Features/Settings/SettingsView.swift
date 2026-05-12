import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query private var settingsList: [AppSettings]
    @State private var requesting = false

    public init() {}

    private var settings: AppSettings {
        if let first = settingsList.first { return first }
        let new = AppSettings()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    public var body: some View {
        let s = settings
        Form {
            Section("settings.permission_section") {
                PermissionStatusView()
            }
            Section("settings.scheduling_section") {
                Stepper(value: Binding(get: { s.lookaheadDays }, set: { s.lookaheadDays = $0; try? modelContext.save(); scheduleRefresh() }), in: 7...90) {
                    Text(String(localized: "settings.lookahead_days") + ": \(s.lookaheadDays)")
                }
                Stepper(value: Binding(get: { s.liveActivityLeadHours }, set: { s.liveActivityLeadHours = $0; try? modelContext.save(); liveActivityEval() }), in: 1...24) {
                    Text(String(localized: "settings.live_activity_lead_hours") + ": \(s.liveActivityLeadHours)")
                }
            }
            Section("settings.sound_section") {
                Picker("settings.default_sound", selection: Binding(get: { s.defaultSoundID }, set: { s.defaultSoundID = $0; try? modelContext.save(); scheduleRefresh() })) {
                    ForEach(AlarmSound.allBuiltIn) { sound in
                        Text(LocalizedStringKey(sound.displayNameKey)).tag(sound.id)
                    }
                }
            }
            Section {
                NavigationLink("settings.holidays") {
                    HolidayManagerView()
                }
                NavigationLink("settings.export") {
                    ExportView()
                }
                NavigationLink("settings.import") {
                    ImportView()
                }
            }
            Section("settings.about") {
                LabeledContent("settings.version", value: appVersionString())
            }
        }
        .navigationTitle("tab.settings")
        .task {
            await dependencies.alarmAuthorization.refresh()
        }
    }

    private func scheduleRefresh() {
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
    }

    private func liveActivityEval() {
        Task { await dependencies.liveActivityController.evaluate() }
    }

    private func appVersionString() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
