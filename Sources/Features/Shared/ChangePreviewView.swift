import SwiftUI

public struct ChangePreviewView: View {
    let preview: ChangePreview
    @Binding var selectedItemIDs: Set<UUID>
    @State private var filter: ChangePreviewFilter = .all

    public init(preview: ChangePreview, selectedItemIDs: Binding<Set<UUID>>) {
        self.preview = preview
        self._selectedItemIDs = selectedItemIDs
    }

    public var body: some View {
        summarySection
        if filteredSections.isEmpty {
            Section {
                Text("change_preview.empty_filter")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(filteredSections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        ChangePreviewRow(item: item, isSelected: selectionBinding(for: item))
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        Section("change_preview.summary_section") {
            LabeledContent("change_preview.summary_added") {
                countText(preview.summary.addedCount)
            }
            LabeledContent("change_preview.summary_updated") {
                countText(preview.summary.updatedCount)
            }
            LabeledContent("change_preview.summary_deleted") {
                countText(preview.summary.deletedCount)
            }
            LabeledContent("change_preview.summary_conflicts") {
                countText(preview.summary.conflictCount)
            }
            LabeledContent("change_preview.summary_warnings") {
                countText(preview.summary.warningCount)
            }
            LabeledContent("change_preview.summary_selected") {
                countText(selectedCount)
            }

            Picker("change_preview.filter", selection: $filter) {
                ForEach(ChangePreviewFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)

            Menu {
                Button {
                    selectedItemIDs = preview.selectableItemIDs
                } label: {
                    Label("change_preview.select_all", systemImage: "checkmark.circle")
                }
                Button {
                    selectedItemIDs.subtract(preview.selectableItemIDs)
                } label: {
                    Label("change_preview.clear_selection", systemImage: "circle")
                }
                Button {
                    selectedItemIDs = Set(
                        preview.items
                            .filter { $0.isSelectable && $0.changeKind != .conflict }
                            .map(\.id)
                    )
                } label: {
                    Label(
                        "change_preview.select_without_conflicts",
                        systemImage: "checkmark.shield"
                    )
                }
                Button {
                    selectedItemIDs = Set(
                        preview.items
                            .filter { $0.isSelectable && $0.changeKind == .update }
                            .map(\.id)
                    )
                } label: {
                    Label(
                        "change_preview.select_updates", systemImage: "arrow.triangle.2.circlepath")
                }
            } label: {
                Label("change_preview.selection_menu", systemImage: "checklist")
            }
            .disabled(preview.selectableItemIDs.isEmpty)
        }
    }

    private var selectedCount: Int {
        preview.selectableItemIDs.intersection(selectedItemIDs).count
    }

    private var filteredSections: [ChangePreviewSection] {
        preview.sections.compactMap { section in
            let items = section.items.filter {
                filter.includes($0, selectedItemIDs: selectedItemIDs)
            }
            guard !items.isEmpty else { return nil }
            return ChangePreviewSection(id: section.id, title: section.title, items: items)
        }
    }

    private func countText(_ value: Int) -> some View {
        Text("\(value)")
            .monospacedDigit()
    }

    private func selectionBinding(for item: ChangePreviewItem) -> Binding<Bool> {
        Binding {
            selectedItemIDs.contains(item.id)
        } set: { isSelected in
            if isSelected {
                selectedItemIDs.insert(item.id)
            } else {
                selectedItemIDs.remove(item.id)
            }
        }
    }
}

private enum ChangePreviewFilter: String, CaseIterable, Identifiable {
    case all
    case added
    case updated
    case conflicts
    case warnings
    case selected

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all:
            "change_preview.filter.all"
        case .added:
            "change_preview.filter.added"
        case .updated:
            "change_preview.filter.updated"
        case .conflicts:
            "change_preview.filter.conflicts"
        case .warnings:
            "change_preview.filter.warnings"
        case .selected:
            "change_preview.filter.selected"
        }
    }

    func includes(_ item: ChangePreviewItem, selectedItemIDs: Set<UUID>) -> Bool {
        switch self {
        case .all:
            true
        case .added:
            item.changeKind == .add
        case .updated:
            item.changeKind == .update
        case .conflicts:
            item.changeKind == .conflict
        case .warnings:
            !item.warnings.isEmpty
        case .selected:
            selectedItemIDs.contains(item.id)
        }
    }
}
