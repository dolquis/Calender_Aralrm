import SwiftData
import SwiftUI
import UIKit

public struct HolidayManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: [SortDescriptor(\HolidayOverride.date)]) private var overrides: [HolidayOverride]
    @Query private var presets: [ShiftPreset]
    @State private var addingDate: Date = .now
    @State private var addingLabel: String = ""
    @State private var isImportingFromCalendar = false
    @State private var calendarAccessDenied = false
    @State private var addingSkip: Bool = true
    @State private var addingReplacementID: UUID?
    @State private var addingKind: HolidayOverride.Kind = .paidLeave

    public init() {}

    public var body: some View {
        Form {
            Section("holiday.bulk_import_section") {
                Button("holiday.bulk_import_jp") {
                    importJapaneseHolidays()
                }
                Button {
                    importFromSystemCalendar()
                } label: {
                    if isImportingFromCalendar {
                        ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("holiday.bulk_import_system_calendar")
                    }
                }
                .disabled(isImportingFromCalendar)
            }

            Section("holiday.add_section") {
                DatePicker("holiday.date", selection: $addingDate, displayedComponents: .date)
                TextField("holiday.label", text: $addingLabel)
                Picker("holiday.kind", selection: $addingKind) {
                    Text("holiday.kind_public").tag(HolidayOverride.Kind.publicHoliday)
                    Text("holiday.kind_paid").tag(HolidayOverride.Kind.paidLeave)
                    Text("holiday.kind_custom").tag(HolidayOverride.Kind.custom)
                }
                Toggle("holiday.skip_alarm", isOn: $addingSkip)
                if !addingSkip {
                    Picker("holiday.replacement", selection: $addingReplacementID) {
                        Text("day.no_preset").tag(UUID?.none)
                        ForEach(presets) { preset in
                            Text(preset.name).tag(UUID?.some(preset.id))
                        }
                    }
                }
                Button("holiday.add") {
                    addEntry()
                }
                .disabled(addingLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("holiday.list_section") {
                if overrides.isEmpty {
                    Text("holiday.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(overrides) { override in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(dateString(override.date))
                                    .font(.subheadline.monospacedDigit())
                                Text(override.label)
                                    .font(.subheadline)
                                Spacer()
                                Text(kindLabel(override.kind))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if override.skipAlarm {
                                Text("holiday.row_skip")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let replacement = override.replacementPreset {
                                Text(
                                    String(localized: "holiday.row_replacement")
                                        + ": \(replacement.name)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("settings.holidays")
        .alert(
            "holiday.calendar_access_denied_title",
            isPresented: $calendarAccessDenied
        ) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.open") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("holiday.calendar_access_denied_message")
        }
    }

    private func importFromSystemCalendar() {
        isImportingFromCalendar = true
        Task {
            defer { isImportingFromCalendar = false }

            guard await EventKitHolidayProvider.shared.requestAccess() else {
                calendarAccessDenied = true
                return
            }

            let calendar = Calendar.current
            let now = Date.now
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let end = calendar.date(byAdding: .year, value: 1, to: now) ?? now

            let entries = await EventKitHolidayProvider.shared.fetchHolidayEntries(
                from: start, to: end)

            var seenDates = Set(overrides.map { calendar.startOfDay(for: $0.date) })
            for entry in entries where !seenDates.contains(entry.date) {
                seenDates.insert(entry.date)
                modelContext.insert(
                    HolidayOverride(
                        date: entry.date,
                        kind: .publicHoliday,
                        label: entry.name,
                        skipAlarm: true
                    ))
            }
            try? modelContext.save()
            await dependencies.alarmScheduler.refreshScheduledAlarms()
        }
    }

    private func importJapaneseHolidays() {
        let entries = HolidayProvider.loadJapaneseHolidays()
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        // Parse date-only strings locally to avoid a UTC midnight day shift.
        formatter.timeZone = .current
        let existingDates: Set<Date> = Set(overrides.map { calendar.startOfDay(for: $0.date) })
        for entry in entries {
            guard let date = formatter.date(from: entry.date) else { continue }
            let day = calendar.startOfDay(for: date)
            if existingDates.contains(day) { continue }
            let override = HolidayOverride(
                date: day,
                kind: .publicHoliday,
                label: entry.name,
                skipAlarm: true
            )
            modelContext.insert(override)
        }
        try? modelContext.save()
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
    }

    private func addEntry() {
        let replacement = addingReplacementID.flatMap { id in presets.first { $0.id == id } }
        let entry = HolidayOverride(
            date: Calendar.current.startOfDay(for: addingDate),
            kind: addingKind,
            label: addingLabel,
            skipAlarm: addingSkip,
            replacementPreset: replacement
        )
        modelContext.insert(entry)
        try? modelContext.save()
        addingLabel = ""
        addingReplacementID = nil
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(overrides[i])
        }
        try? modelContext.save()
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter.string(from: date)
    }

    private func kindLabel(_ kind: HolidayOverride.Kind) -> LocalizedStringKey {
        switch kind {
        case .publicHoliday: "holiday.kind_public"
        case .paidLeave: "holiday.kind_paid"
        case .custom: "holiday.kind_custom"
        }
    }
}
