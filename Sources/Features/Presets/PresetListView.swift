import SwiftData
import SwiftUI

public struct PresetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: [SortDescriptor(\ShiftPreset.createdAt)]) private var presets: [ShiftPreset]
    @State private var editingPreset: ShiftPreset?
    @State private var creatingPreset = false

    public init() {}

    public var body: some View {
        List {
            if presets.isEmpty {
                ContentUnavailableView {
                    Label("preset.empty_title", systemImage: "alarm")
                } description: {
                    Text("preset.empty_subtitle")
                } actions: {
                    Button("preset.empty_action") {
                        creatingPreset = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(presets) { preset in
                    Button {
                        editingPreset = preset
                    } label: {
                        row(for: preset)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("tab.presets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creatingPreset = true
                } label: {
                    Label("preset.new", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $creatingPreset) {
            PresetEditorView(preset: nil)
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorView(preset: preset)
        }
    }

    @ViewBuilder
    private func row(for preset: ShiftPreset) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: preset.colorHex))
                .frame(width: 10, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)
                if let h = preset.defaultAlarmHour, let m = preset.defaultAlarmMinute {
                    Text(String(format: "%02d:%02d", h, m))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("preset.no_default_time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if preset.bedtimeLeadMinutes > 0 {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("preset.bedtime_reminder"))
            }
            if preset.soundID != AlarmSound.systemDefault.id {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("preset.sound"))
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(presets[i])
        }
        try? modelContext.save()
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
    }
}
