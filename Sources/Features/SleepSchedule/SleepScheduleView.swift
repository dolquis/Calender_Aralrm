import SwiftUI
import SwiftData

public struct SleepScheduleView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext

    @State private var windows: [SleepWindow] = []
    @State private var showShortcutsGuide = false
    @State private var healthKitGranted = false

    private var upcomingWindows: [SleepWindow] { windows.filter { $0.wakeTime > .now } }

    public init() {}

    public var body: some View {
        List {
            shortcutsSection
            healthKitSection
            windowsSection
        }
        .navigationTitle("sleep.nav_title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showShortcutsGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("sleep.shortcuts_guide_button")
            }
        }
        .sheet(isPresented: $showShortcutsGuide) {
            ShortcutsOnboardingView()
        }
        .task {
            await loadWindows()
            healthKitGranted = await dependencies.sleepSampleWriter.requestAuthorization()
            if healthKitGranted {
                await dependencies.sleepSampleWriter.writePastSamples(from: windows)
            }
        }
    }

    private var shortcutsSection: some View {
        Section {
            Button {
                showShortcutsGuide = true
            } label: {
                Label("sleep.shortcuts_setup", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: {
            Text("sleep.section_shortcuts")
        } footer: {
            Text("sleep.shortcuts_footer")
        }
    }

    private var healthKitSection: some View {
        Section {
            if dependencies.sleepSampleWriter.isAvailable {
                if healthKitGranted {
                    Label("sleep.healthkit_enabled", systemImage: "heart.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task {
                            healthKitGranted = await dependencies.sleepSampleWriter.requestAuthorization()
                            if healthKitGranted {
                                await dependencies.sleepSampleWriter.writePastSamples(from: windows)
                            }
                        }
                    } label: {
                        Label("sleep.healthkit_authorize", systemImage: "heart")
                    }
                }
            } else {
                Label("sleep.healthkit_unavailable", systemImage: "heart.slash")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("sleep.section_healthkit")
        } footer: {
            Text("sleep.healthkit_footer")
        }
    }

    private var windowsSection: some View {
        Section("sleep.section_upcoming") {
            if upcomingWindows.isEmpty {
                ContentUnavailableView(
                    "sleep.no_windows_title",
                    systemImage: "moon.zzz",
                    description: Text("sleep.no_windows_description")
                )
            } else {
                ForEach(upcomingWindows, id: \.date) { window in
                    SleepWindowRow(window: window)
                }
            }
        }
    }

    private func loadWindows() async {
        let context = ModelContext(dependencies.modelContainer)
        let calendar = Calendar.current
        let input = await AlarmScheduler.buildResolverInput(context: context, calendar: calendar)
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        // Include 14 past days so writePastSamples has real historical windows to persist,
        // plus the full future lookahead for display. upcomingWindows filters for UI.
        let historyStart = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now
        let totalDays = 14 + settings.lookaheadDays
        let days = Array(DayRange(start: historyStart, dayCount: totalDays, calendar: calendar))
        windows = SleepWindowResolver.resolve(dates: days, input: input)
    }
}

private struct SleepWindowRow: View {
    let window: SleepWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(window.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Label(window.bedtime.formatted(date: .omitted, time: .shortened), systemImage: "moon.fill")
                    .foregroundStyle(.indigo)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Label(window.wakeTime.formatted(date: .omitted, time: .shortened), systemImage: "sun.max.fill")
                    .foregroundStyle(.orange)
            }
            .font(.body.monospacedDigit())
            if let reminder = window.reminderFireDate {
                Text("sleep.reminder_at \(reminder.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
