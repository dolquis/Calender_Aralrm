import CryptoKit
import Foundation

public struct ChangePreview: Equatable, Sendable {
    public var summary: ChangeSummary
    public var sections: [ChangePreviewSection]

    public init(summary: ChangeSummary, sections: [ChangePreviewSection]) {
        self.summary = summary
        self.sections = sections
    }

    public init(sections: [ChangePreviewSection]) {
        self.sections = sections
        self.summary = ChangeSummary(items: sections.flatMap(\.items))
    }

    public var items: [ChangePreviewItem] {
        sections.flatMap(\.items)
    }

    public var selectableItemIDs: Set<UUID> {
        Set(items.filter(\.isSelectable).map(\.id))
    }

    public var selectedItemIDs: Set<UUID> {
        Set(items.filter { $0.isSelected && $0.isSelectable }.map(\.id))
    }

    public func hasSelectedChanges(_ selectedIDs: Set<UUID>) -> Bool {
        !selectableItemIDs.intersection(selectedIDs).isEmpty
    }

    public mutating func replaceSelection(with selectedIDs: Set<UUID>) {
        sections = sections.map { section in
            var next = section
            next.items = section.items.map { item in
                var nextItem = item
                nextItem.isSelected = item.isSelectable && selectedIDs.contains(item.id)
                return nextItem
            }
            return next
        }
    }
}

public struct ChangeSummary: Equatable, Sendable {
    public var addedCount: Int
    public var updatedCount: Int
    public var deletedCount: Int
    public var unchangedCount: Int
    public var conflictCount: Int
    public var warningCount: Int

    public init(
        addedCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        unchangedCount: Int = 0,
        conflictCount: Int = 0,
        warningCount: Int = 0
    ) {
        self.addedCount = addedCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.unchangedCount = unchangedCount
        self.conflictCount = conflictCount
        self.warningCount = warningCount
    }

    public init(items: [ChangePreviewItem]) {
        self.init()
        for item in items {
            switch item.changeKind {
            case .add:
                addedCount += 1
            case .update:
                updatedCount += 1
            case .delete:
                deletedCount += 1
            case .unchanged:
                unchangedCount += 1
            case .conflict:
                conflictCount += 1
            }
            if !item.warnings.isEmpty {
                warningCount += 1
            }
        }
    }

    public var hasChanges: Bool {
        addedCount + updatedCount + deletedCount > 0
    }
}

public struct ChangePreviewSection: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var items: [ChangePreviewItem]

    public init(id: UUID, title: String, items: [ChangePreviewItem]) {
        self.id = id
        self.title = title
        self.items = items
    }

    public init(sourcePath: String, title: String, items: [ChangePreviewItem]) {
        self.init(
            id: ChangePreviewItem.deterministicSectionID(sourcePath),
            title: title,
            items: items
        )
    }
}

public struct ChangePreviewItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sourcePath: String
    public var date: Date?
    public var entityKind: ChangeEntityKind
    public var entityID: UUID?
    public var changeKind: ChangeKind
    public var beforeText: LocalizedStringResource?
    public var afterText: LocalizedStringResource?
    public var warnings: [LocalizedStringResource]
    public var isSelected: Bool

    public init(
        id: UUID,
        sourcePath: String,
        date: Date? = nil,
        entityKind: ChangeEntityKind,
        entityID: UUID? = nil,
        changeKind: ChangeKind,
        beforeText: LocalizedStringResource? = nil,
        afterText: LocalizedStringResource? = nil,
        warnings: [LocalizedStringResource] = [],
        isSelected: Bool? = nil
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.date = date
        self.entityKind = entityKind
        self.entityID = entityID
        self.changeKind = changeKind
        self.beforeText = beforeText
        self.afterText = afterText
        self.warnings = warnings
        self.isSelected = isSelected ?? changeKind.isSelectableByDefault
    }

    public init(
        sourcePath: String,
        date: Date? = nil,
        entityKind: ChangeEntityKind,
        entityID: UUID? = nil,
        changeKind: ChangeKind,
        beforeText: LocalizedStringResource? = nil,
        afterText: LocalizedStringResource? = nil,
        warnings: [LocalizedStringResource] = [],
        isSelected: Bool? = nil
    ) {
        self.init(
            id: Self.deterministicID(
                entityKind: entityKind,
                sourcePath: sourcePath,
                date: date,
                entityID: entityID
            ),
            sourcePath: sourcePath,
            date: date,
            entityKind: entityKind,
            entityID: entityID,
            changeKind: changeKind,
            beforeText: beforeText,
            afterText: afterText,
            warnings: warnings,
            isSelected: isSelected
        )
    }

    public var isSelectable: Bool {
        changeKind.isSelectableByDefault
    }

    public static func deterministicID(
        entityKind: ChangeEntityKind,
        sourcePath: String,
        date: Date? = nil,
        entityID: UUID? = nil
    ) -> UUID {
        let datePart =
            date.map { String(Int64(($0.timeIntervalSince1970 * 1000).rounded())) } ?? "-"
        return uuid(
            for: [
                entityKind.rawValue,
                sourcePath,
                datePart,
                entityID?.uuidString ?? "-",
            ].joined(separator: "|")
        )
    }

    public static func deterministicSectionID(_ sourcePath: String) -> UUID {
        uuid(for: "section|\(sourcePath)")
    }

    private static func uuid(for raw: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(raw.utf8)))
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
}

public enum ChangeKind: String, Sendable {
    case add
    case update
    case delete
    case unchanged
    case conflict

    public var isSelectableByDefault: Bool {
        switch self {
        case .add, .update, .delete:
            true
        case .unchanged, .conflict:
            false
        }
    }
}

public enum ChangeEntityKind: String, Sendable {
    case preset
    case dayAssignment
    case rotationPattern
    case holidayOverride
    case vacationPeriod
    case dowRule
}
