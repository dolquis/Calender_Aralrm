import Foundation
import Testing

@testable import ShiftAlarm

struct ChangePreviewTests {
    @Test
    func testDeterministicIDUsesSourcePath() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = ChangePreviewItem.deterministicID(
            entityKind: .dayAssignment,
            sourcePath: "shiftalarm:assignments[0]",
            date: date
        )
        let rebuilt = ChangePreviewItem.deterministicID(
            entityKind: .dayAssignment,
            sourcePath: "shiftalarm:assignments[0]",
            date: date
        )
        let otherSource = ChangePreviewItem.deterministicID(
            entityKind: .dayAssignment,
            sourcePath: "shiftalarm:assignments[1]",
            date: date
        )

        #expect(first == rebuilt)
        #expect(first != otherSource)
    }

    @Test
    func testSummaryCountsKindsAndWarnings() {
        let add = ChangePreviewItem(
            sourcePath: "shiftalarm:presets[0]",
            entityKind: .preset,
            changeKind: .add
        )
        let updateWithWarning = ChangePreviewItem(
            sourcePath: "shiftalarm:assignments[0]",
            entityKind: .dayAssignment,
            changeKind: .update,
            warnings: ["warning"]
        )
        let conflict = ChangePreviewItem(
            sourcePath: "shiftalarm:assignments[1].date",
            entityKind: .dayAssignment,
            changeKind: .conflict
        )

        let preview = ChangePreview(sections: [
            ChangePreviewSection(
                sourcePath: "test", title: "Test",
                items: [
                    add,
                    updateWithWarning,
                    conflict,
                ])
        ])

        #expect(preview.summary.addedCount == 1)
        #expect(preview.summary.updatedCount == 1)
        #expect(preview.summary.conflictCount == 1)
        #expect(preview.summary.warningCount == 1)
    }

    @Test
    func testReplaceSelectionKeepsOnlySelectableItems() {
        let add = ChangePreviewItem(
            sourcePath: "shiftalarm:presets[0]",
            entityKind: .preset,
            changeKind: .add
        )
        let conflict = ChangePreviewItem(
            sourcePath: "shiftalarm:assignments[0].date",
            entityKind: .dayAssignment,
            changeKind: .conflict
        )
        var preview = ChangePreview(sections: [
            ChangePreviewSection(sourcePath: "test", title: "Test", items: [add, conflict])
        ])

        preview.replaceSelection(with: [add.id, conflict.id])

        #expect(preview.selectedItemIDs == [add.id])
        #expect(preview.hasSelectedChanges([add.id]))
        #expect(!preview.hasSelectedChanges([conflict.id]))
    }
}
