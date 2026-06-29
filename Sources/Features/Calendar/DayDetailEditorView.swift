import SwiftData
import SwiftUI

public struct DayDetailEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query private var presets: [ShiftPreset]
    @Query private var assignments: [DayAssignment]
    @Query private var swapRecords: [SwapRecord]

    public let date: Date

    @State private var selectedPresetID: UUID?
    @State private var customTimeEnabled = false
    @State private var customTime: Date = Date()
    @State private var skipAlarm = false
    @State private var note: String = ""
    @State private var swapEnabled = false
    @State private var swapKind: SwapRecord.Kind = .covered
    @State private var swapCounterpartyLabel = ""
    @State private var swapNote = ""
    @State private var loadedAssignmentDraft: DayAssignmentDraft?
    @State private var preSwapAssignmentDraft: DayAssignmentDraft?

    public init(date: Date) {
        self.date = date
    }

    private var existingAssignment: DayAssignment? {
        let day = Calendar.current.startOfDay(for: date)
        return assignments.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private var existingSwapRecords: [SwapRecord] {
        let day = Calendar.current.startOfDay(for: date)
        return swapRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private var existingSwapRecord: SwapRecord? {
        existingSwapRecords.first
    }

    private var trimmedSwapCounterpartyLabel: String {
        swapCounterpartyLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard swapEnabled else { return true }
        guard !trimmedSwapCounterpartyLabel.isEmpty else { return false }
        switch swapKind {
        case .covered:
            return true
        case .covering, .exchange:
            return selectedPresetID != nil
        }
    }

    private var currentAssignmentDraft: DayAssignmentDraft {
        let timeComponents =
            customTimeEnabled
            ? Calendar.current.dateComponents([.hour, .minute], from: customTime) : nil
        return DayAssignmentDraft(
            presetID: selectedPresetID,
            overrideAlarmHour: timeComponents?.hour,
            overrideAlarmMinute: timeComponents?.minute,
            skipAlarm: skipAlarm,
            note: note
        )
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("day.preset", selection: $selectedPresetID) {
                        Text("day.no_preset").tag(UUID?.none)
                        ForEach(presets) { preset in
                            Text(preset.name).tag(UUID?.some(preset.id))
                        }
                    }
                }

                Section("day.alarm_time") {
                    Toggle("day.override_time", isOn: $customTimeEnabled)
                    if customTimeEnabled {
                        DatePicker(
                            "day.time",
                            selection: $customTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Toggle("day.skip_alarm", isOn: $skipAlarm)
                }

                Section("day.note") {
                    TextField("day.note_placeholder", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("day.swap_section") {
                    Toggle("day.swap_enabled", isOn: $swapEnabled)
                    if swapEnabled {
                        Picker("day.swap_kind", selection: $swapKind) {
                            ForEach(SwapRecord.Kind.manuallyEditableCases, id: \.self) { kind in
                                Text(title(for: kind)).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField(
                            "day.swap_counterparty_placeholder",
                            text: $swapCounterpartyLabel
                        )
                        TextField("day.swap_note_placeholder", text: $swapNote, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
            }
            .navigationTitle(formattedDate)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: swapEnabled) { _, enabled in
                if enabled {
                    preSwapAssignmentDraft = currentAssignmentDraft
                    applySwapDefaults(for: swapKind)
                } else {
                    restorePreSwapAssignmentDraft()
                }
            }
            .onChange(of: swapKind) { _, kind in
                guard swapEnabled else { return }
                applySwapDefaults(for: kind)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        return formatter.string(from: date)
    }

    private func load() {
        if let assignment = existingAssignment {
            let draft = DayAssignmentDraft(assignment: assignment)
            loadedAssignmentDraft = draft
            selectedPresetID = assignment.preset?.id
            skipAlarm = assignment.skipAlarm
            note = assignment.note
            if let h = assignment.overrideAlarmHour, let m = assignment.overrideAlarmMinute {
                customTimeEnabled = true
                var dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
                dc.hour = h
                dc.minute = m
                customTime = Calendar.current.date(from: dc) ?? Date()
            }
        }

        if let swap = existingSwapRecord {
            swapEnabled = true
            swapKind = swap.kind
            swapCounterpartyLabel = swap.counterpartyLabel
            swapNote = swap.note
            preSwapAssignmentDraft = loadedAssignmentDraft
        }
    }

    private func save() {
        guard canSave else { return }
        let day = Calendar.current.startOfDay(for: date)
        applyAssignmentAction(
            DayDetailEditorSavePlanner.assignmentAction(
                currentDraft: currentAssignmentDraft,
                swapEnabled: swapEnabled,
                swapKind: swapKind,
                hasExistingAssignment: existingAssignment != nil,
                existingSwapKind: existingSwapRecord?.kind,
                loadedAssignmentDraft: loadedAssignmentDraft
            ),
            day: day
        )
        saveSwapRecord(for: day)
        try? modelContext.save()
        Task {
            await dependencies.alarmScheduler.refreshScheduledAlarms()
            await dependencies.liveActivityController.evaluate()
        }
        dismiss()
    }

    private func applyAssignmentAction(_ action: DayAssignmentPersistenceAction, day: Date) {
        switch action {
        case .none:
            return
        case .delete:
            if let assignment = existingAssignment {
                modelContext.delete(assignment)
            }
        case .upsert(let draft):
            let preset = draft.presetID.flatMap { id in presets.first { $0.id == id } }
            if let assignment = existingAssignment {
                assignment.preset = preset
                assignment.skipAlarm = draft.skipAlarm
                assignment.note = draft.note
                assignment.overrideAlarmHour = draft.overrideAlarmHour
                assignment.overrideAlarmMinute = draft.overrideAlarmMinute
            } else {
                let assignment = DayAssignment(
                    date: day,
                    preset: preset,
                    overrideAlarmHour: draft.overrideAlarmHour,
                    overrideAlarmMinute: draft.overrideAlarmMinute,
                    skipAlarm: draft.skipAlarm,
                    note: draft.note
                )
                modelContext.insert(assignment)
            }
        }
    }

    private func saveSwapRecord(for day: Date) {
        if swapEnabled {
            let record =
                existingSwapRecord
                ?? SwapRecord(
                    date: day,
                    kind: swapKind,
                    counterpartyLabel: trimmedSwapCounterpartyLabel,
                    note: swapNote
                )
            record.date = day
            record.kind = swapKind
            record.counterpartyLabel = trimmedSwapCounterpartyLabel
            record.note = swapNote
            if existingSwapRecord == nil {
                modelContext.insert(record)
            }
            for duplicate in existingSwapRecords.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            for record in existingSwapRecords {
                modelContext.delete(record)
            }
        }
    }

    private func applySwapDefaults(for kind: SwapRecord.Kind) {
        switch kind {
        case .covered:
            selectedPresetID = nil
            customTimeEnabled = false
            skipAlarm = true
        case .covering, .exchange:
            skipAlarm = false
        }
    }

    private func restorePreSwapAssignmentDraft() {
        guard let draft = preSwapAssignmentDraft else { return }
        selectedPresetID = draft.presetID
        if let hour = draft.overrideAlarmHour, let minute = draft.overrideAlarmMinute {
            customTimeEnabled = true
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
            dc.hour = hour
            dc.minute = minute
            customTime = Calendar.current.date(from: dc) ?? Date()
        } else {
            customTimeEnabled = false
        }
        skipAlarm = draft.skipAlarm
        note = draft.note
    }

    private func title(for kind: SwapRecord.Kind) -> LocalizedStringKey {
        switch kind {
        case .covered:
            return "day.swap_kind_covered"
        case .covering:
            return "day.swap_kind_covering"
        case .exchange:
            return "day.swap_kind_exchange"
        }
    }
}
