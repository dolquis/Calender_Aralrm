import SwiftUI
import SwiftData

public struct RotationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: [SortDescriptor(\ShiftPreset.createdAt)]) private var presets: [ShiftPreset]

    let pattern: RotationPattern?

    @State private var name: String = ""
    @State private var cycleLength: Int = 6
    @State private var slots: [UUID?] = Array(repeating: nil, count: 6)
    @State private var anchorDate: Date = .now
    @State private var hasStartDate = false
    @State private var startDate: Date = .now
    @State private var hasEndDate = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var priority: Int = 0
    @State private var isActive: Bool = true

    public init(pattern: RotationPattern?) {
        self.pattern = pattern
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("rotation.name_section") {
                    TextField("rotation.name_placeholder", text: $name)
                }
                Section("rotation.cycle_section") {
                    Stepper(value: $cycleLength, in: 1...28) {
                        Text(String(localized: "rotation.cycle_label") + ": \(cycleLength)")
                    }
                    .onChange(of: cycleLength) { _, newValue in
                        resizeSlots(to: newValue)
                    }
                }
                Section("rotation.slots_section") {
                    ForEach(0..<cycleLength, id: \.self) { idx in
                        Picker(selection: bindingForSlot(idx)) {
                            Text("rotation.rest_day").tag(UUID?.none)
                            ForEach(presets) { p in
                                Text(p.name).tag(UUID?.some(p.id))
                            }
                        } label: {
                            Text(String(localized: "rotation.day_n") + " \(idx + 1)")
                        }
                    }
                }
                Section("rotation.range_section") {
                    DatePicker("rotation.anchor", selection: $anchorDate, displayedComponents: .date)
                    Toggle("rotation.has_start", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("rotation.start", selection: $startDate, displayedComponents: .date)
                    }
                    Toggle("rotation.has_end", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("rotation.end", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("rotation.flags_section") {
                    Stepper(value: $priority, in: 0...10) {
                        Text(String(localized: "rotation.priority") + ": \(priority)")
                    }
                    Toggle("rotation.active", isOn: $isActive)
                }
                Section("rotation.preview_section") {
                    RotationPreviewView(
                        anchor: anchorDate,
                        cycleLength: cycleLength,
                        slots: slots,
                        presets: presets,
                        startDate: hasStartDate ? startDate : nil,
                        endDate: hasEndDate ? endDate : nil
                    )
                }
            }
            .navigationTitle(pattern == nil ? Text("rotation.new") : Text("rotation.edit"))
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

    private func bindingForSlot(_ idx: Int) -> Binding<UUID?> {
        Binding(
            get: { slots.indices.contains(idx) ? slots[idx] : nil },
            set: { newValue in
                if slots.indices.contains(idx) {
                    slots[idx] = newValue
                }
            }
        )
    }

    private func resizeSlots(to count: Int) {
        if count > slots.count {
            slots.append(contentsOf: Array(repeating: nil, count: count - slots.count))
        } else if count < slots.count {
            slots = Array(slots.prefix(count))
        }
    }

    private func load() {
        guard let pattern else { return }
        name = pattern.name
        cycleLength = pattern.cycleLength
        slots = pattern.slots
        anchorDate = pattern.anchorDate
        if let s = pattern.startDate {
            hasStartDate = true
            startDate = s
        }
        if let e = pattern.endDate {
            hasEndDate = true
            endDate = e
        }
        priority = pattern.priority
        isActive = pattern.isActive
    }

    private func save() {
        let normalizedSlots: [UUID?] = {
            var s = slots
            if s.count < cycleLength {
                s.append(contentsOf: Array(repeating: nil, count: cycleLength - s.count))
            } else if s.count > cycleLength {
                s = Array(s.prefix(cycleLength))
            }
            return s
        }()
        if let pattern {
            pattern.name = name
            pattern.cycleLength = cycleLength
            pattern.slots = normalizedSlots
            pattern.anchorDate = anchorDate
            pattern.startDate = hasStartDate ? startDate : nil
            pattern.endDate = hasEndDate ? endDate : nil
            pattern.priority = priority
            pattern.isActive = isActive
        } else {
            let new = RotationPattern(
                name: name,
                anchorDate: anchorDate,
                cycleLength: cycleLength,
                slots: normalizedSlots,
                startDate: hasStartDate ? startDate : nil,
                endDate: hasEndDate ? endDate : nil,
                priority: priority,
                isActive: isActive
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
        dismiss()
    }
}
