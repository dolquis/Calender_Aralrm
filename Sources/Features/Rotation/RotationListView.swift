import SwiftUI
import SwiftData

public struct RotationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: [SortDescriptor(\RotationPattern.priority, order: .reverse)]) private var patterns: [RotationPattern]
    @State private var editing: RotationPattern?
    @State private var creating = false

    public init() {}

    public var body: some View {
        List {
            if patterns.isEmpty {
                ContentUnavailableView(
                    "rotation.empty_title",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("rotation.empty_subtitle")
                )
            } else {
                ForEach(patterns) { pattern in
                    Button {
                        editing = pattern
                    } label: {
                        row(for: pattern)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("tab.rotation")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $creating) { RotationEditorView(pattern: nil) }
        .sheet(item: $editing) { p in RotationEditorView(pattern: p) }
    }

    private func row(for pattern: RotationPattern) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pattern.name).font(.headline)
                if !pattern.isActive {
                    Text("rotation.inactive")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            Text(String(localized: "rotation.cycle_label") + ": \(pattern.cycleLength)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(patterns[i])
        }
        try? modelContext.save()
        Task {
            await dependencies.alarmScheduler.refreshScheduledAlarms()
            await dependencies.liveActivityController.evaluate()
        }
    }
}
