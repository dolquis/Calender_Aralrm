import SwiftUI

public struct ChangePreviewRow: View {
    let item: ChangePreviewItem
    @Binding var isSelected: Bool

    public init(item: ChangePreviewItem, isSelected: Binding<Bool>) {
        self.item = item
        self._isSelected = isSelected
    }

    public var body: some View {
        Group {
            if item.isSelectable {
                Toggle(isOn: $isSelected) {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label {
                    Text(item.changeKind.title)
                } icon: {
                    Image(systemName: item.changeKind.systemImage)
                        .accessibilityHidden(true)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.changeKind.tint)

                Text(item.entityKind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            if let beforeText = item.beforeText {
                valueBlock(title: "change_preview.before", value: beforeText)
            }
            if let afterText = item.afterText {
                valueBlock(title: "change_preview.after", value: afterText)
            }

            if !item.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(item.warnings.enumerated()), id: \.offset) { _, warning in
                        Label {
                            Text(warning)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let date = item.date {
                    Text(date, format: .dateTime.year().month().day())
                }
                Text(item.sourcePath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func valueBlock(
        title: LocalizedStringResource,
        value: LocalizedStringResource
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension ChangeKind {
    fileprivate var title: LocalizedStringResource {
        switch self {
        case .add:
            "change_preview.kind.add"
        case .update:
            "change_preview.kind.update"
        case .delete:
            "change_preview.kind.delete"
        case .unchanged:
            "change_preview.kind.unchanged"
        case .conflict:
            "change_preview.kind.conflict"
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .add:
            "plus.circle"
        case .update:
            "arrow.triangle.2.circlepath"
        case .delete:
            "minus.circle"
        case .unchanged:
            "checkmark.circle"
        case .conflict:
            "exclamationmark.triangle"
        }
    }

    fileprivate var tint: Color {
        switch self {
        case .add:
            .green
        case .update:
            .blue
        case .delete, .conflict:
            .red
        case .unchanged:
            .secondary
        }
    }
}

extension ChangeEntityKind {
    fileprivate var title: LocalizedStringResource {
        switch self {
        case .preset:
            "change_preview.entity.preset"
        case .dayAssignment:
            "change_preview.entity.day_assignment"
        case .rotationPattern:
            "change_preview.entity.rotation_pattern"
        case .holidayOverride:
            "change_preview.entity.holiday_override"
        case .vacationPeriod:
            "change_preview.entity.vacation_period"
        case .dowRule:
            "change_preview.entity.dow_rule"
        }
    }
}
