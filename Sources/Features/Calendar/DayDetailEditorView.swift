import SwiftData
import SwiftUI

public struct DayDetailEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query private var presets: [ShiftPreset]
    @Query private var assignments: [DayAssignment]

    public let date: Date

    @State private var selectedPresetID: UUID?
    @State private var customTimeEnabled = false
    @State private var customTime: Date = Date()
    @State private var skipAlarm = false
    @State private var note: String = ""

    public init(date: Date) {
        self.date = date
    }

    private var existingAssignment: DayAssignment? {
        let day = Calendar.current.startOfDay(for: date)
        return assignments.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
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
            }
            .navigationTitle(formattedDate)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func isNonEmpty(
        preset: ShiftPreset?, timeComponents: (Int, Int)?, skipAlarm: Bool, note: String
    ) -> Bool {
        preset != nil || timeComponents != nil || skipAlarm
            || !note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        return formatter.string(from: date)
    }

    private func load() {
        guard let assignment = existingAssignment else { return }
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

    private func save() {
        let day = Calendar.current.startOfDay(for: date)
        let preset = selectedPresetID.flatMap { id in presets.first { $0.id == id } }
        let timeComponents: (Int, Int)? =
            customTimeEnabled
            ? {
                let dc = Calendar.current.dateComponents([.hour, .minute], from: customTime)
                return (dc.hour ?? 0, dc.minute ?? 0)
            }() : nil

        if let assignment = existingAssignment {
            assignment.preset = preset
            assignment.skipAlarm = skipAlarm
            assignment.note = note
            assignment.overrideAlarmHour = timeComponents?.0
            assignment.overrideAlarmMinute = timeComponents?.1
        } else if isNonEmpty(
            preset: preset, timeComponents: timeComponents, skipAlarm: skipAlarm, note: note)
        {
            // Only create a new manual assignment when the user actually specified something.
            // A blank record would take precedence over rotation/holiday rules in DayResolver
            // and suppress the alarm for that day.
            let assignment = DayAssignment(
                date: day,
                preset: preset,
                overrideAlarmHour: timeComponents?.0,
                overrideAlarmMinute: timeComponents?.1,
                skipAlarm: skipAlarm,
                note: note
            )
            modelContext.insert(assignment)
        }
        try? modelContext.save()
        Task {
            await dependencies.alarmScheduler.refreshScheduledAlarms()
            await dependencies.liveActivityController.evaluate()
        }
        dismiss()
    }
}
