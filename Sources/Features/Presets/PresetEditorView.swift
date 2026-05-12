import SwiftUI
import SwiftData

public struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies

    let preset: ShiftPreset?

    @State private var name: String = ""
    @State private var colorHex: String = Color.presetPalette.first ?? "#1E88E5"
    @State private var alarmEnabled: Bool = true
    @State private var alarmTime: Date = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    @State private var soundID: String = AlarmSound.systemDefault.id
    @State private var note: String = ""

    public init(preset: ShiftPreset?) {
        self.preset = preset
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("preset.name_section") {
                    TextField("preset.name_placeholder", text: $name)
                }
                Section("preset.color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 36)), count: 8)) {
                        ForEach(Color.presetPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: hex == colorHex ? 2 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("preset.default_alarm") {
                    Toggle("preset.enable_default_time", isOn: $alarmEnabled)
                    if alarmEnabled {
                        DatePicker(
                            "preset.alarm_time",
                            selection: $alarmTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
                Section("preset.sound") {
                    Picker("preset.sound", selection: $soundID) {
                        ForEach(AlarmSound.allBuiltIn) { sound in
                            Text(LocalizedStringKey(sound.displayNameKey)).tag(sound.id)
                        }
                    }
                }
                Section("preset.note") {
                    TextField("preset.note_placeholder", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(preset == nil ? Text("preset.new") : Text("preset.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let preset else { return }
        name = preset.name
        colorHex = preset.colorHex
        soundID = preset.soundID
        note = preset.note
        if let h = preset.defaultAlarmHour, let m = preset.defaultAlarmMinute {
            alarmEnabled = true
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            dc.hour = h
            dc.minute = m
            alarmTime = Calendar.current.date(from: dc) ?? .now
        } else {
            alarmEnabled = false
        }
    }

    private func save() {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
        if let existing = preset {
            existing.name = name
            existing.colorHex = colorHex
            existing.soundID = soundID
            existing.note = note
            existing.defaultAlarmHour = alarmEnabled ? timeComponents.hour : nil
            existing.defaultAlarmMinute = alarmEnabled ? timeComponents.minute : nil
        } else {
            let new = ShiftPreset(
                name: name,
                colorHex: colorHex,
                defaultAlarmHour: alarmEnabled ? timeComponents.hour : nil,
                defaultAlarmMinute: alarmEnabled ? timeComponents.minute : nil,
                soundID: soundID,
                note: note
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        Task {
            await dependencies.alarmScheduler.refreshScheduledAlarms()
            await dependencies.liveActivityController.evaluate()
        }
        dismiss()
    }
}
