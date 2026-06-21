import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
struct ShareImporterTests {

    private func makeBundle(
        presetID: UUID = UUID(),
        anchorYear: Int = 2026,
        anchorMonth: Int = 5,
        anchorDay: Int = 1
    ) -> ShiftBundle {
        let anchor = CalendarDay(year: anchorYear, month: anchorMonth, day: anchorDay)
        return ShiftBundle(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            presets: [
                ShiftBundle.PresetDTO(
                    id: presetID,
                    name: "Day",
                    colorHex: "#1E88E5",
                    defaultAlarmHour: 7,
                    defaultAlarmMinute: 0,
                    soundID: AlarmSound.systemDefault.id,
                    note: ""
                )
            ],
            patterns: [
                ShiftBundle.RotationDTO(
                    id: UUID(),
                    name: "5on2off",
                    anchorDate: anchor,
                    cycleLength: 7,
                    slots: [presetID, presetID, presetID, presetID, presetID, nil, nil],
                    startDate: nil,
                    endDate: nil,
                    priority: 0,
                    isActive: true
                )
            ],
            assignments: [
                ShiftBundle.AssignmentDTO(
                    date: anchor,
                    presetID: presetID,
                    overrideAlarmHour: 8,
                    overrideAlarmMinute: 30,
                    skipAlarm: false,
                    note: "early"
                )
            ],
            overrides: [
                ShiftBundle.OverrideDTO(
                    date: CalendarDay(year: anchorYear, month: anchorMonth, day: anchorDay + 1),
                    kind: .publicHoliday,
                    label: "Holiday",
                    skipAlarm: true,
                    replacementPresetID: nil
                )
            ]
        )
    }
    @Test
    func testPreviewCounts_freshContainer() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()
        let preview = ShareImporter.preview(bundle: bundle, container: container)

        #expect(preview.addedPresets == 1)
        #expect(preview.updatedPresets == 0)
        #expect(preview.addedPatterns == 1)
        #expect(preview.updatedPatterns == 0)
        #expect(preview.addedAssignments == 1)
        #expect(preview.updatedAssignments == 0)
        #expect(preview.addedOverrides == 1)
        #expect(preview.updatedOverrides == 0)
        #expect(preview.hasChanges)
        #expect(preview.changePreview.summary.addedCount == 4)
        #expect(preview.changePreview.selectedItemIDs.count == 4)
    }

    @Test
    func testPreviewItemIDsAreDeterministic() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()

        let first = ShareImporter.preview(bundle: bundle, container: container)
        let second = ShareImporter.preview(bundle: bundle, container: container)

        #expect(first.changePreview.items.map(\.id) == second.changePreview.items.map(\.id))
        #expect(
            first.changePreview.items.map(\.sourcePath) == [
                "shiftalarm:presets[0]",
                "shiftalarm:patterns[0]",
                "shiftalarm:assignments[0]",
                "shiftalarm:overrides[0]",
            ])
    }

    @Test
    func testPreviewAttachesValidatorWarnings() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.presets[0].colorHex = "blue"

        let preview = ShareImporter.preview(bundle: bundle, container: container)
        let presetItem = preview.changePreview.items.first {
            $0.sourcePath == "shiftalarm:presets[0]"
        }

        #expect(preview.validation.warnings.count == 1)
        #expect(preview.changePreview.summary.warningCount == 1)
        #expect(presetItem?.warnings.count == 1)
        #expect(preview.canApply)
    }

    @Test
    func testPreviewShowsValidationErrorsAsConflicts() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.assignments.append(bundle.assignments[0])

        let preview = ShareImporter.preview(bundle: bundle, container: container)

        #expect(!preview.validation.isValid)
        #expect(preview.changePreview.summary.conflictCount == 1)
        #expect(!preview.canApply)
    }

    @Test
    func testPreviewAssignmentInheritsPresetDefaultAlarm() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.assignments[0].overrideAlarmHour = nil
        bundle.assignments[0].overrideAlarmMinute = nil

        let preview = ShareImporter.preview(bundle: bundle, container: container)
        let assignmentItem = try #require(
            preview.changePreview.items.first {
                $0.sourcePath == "shiftalarm:assignments[0]"
            }
        )
        let afterText = try #require(assignmentItem.afterText)
        let inheritedText = String(
            format: String(localized: "change_preview.alarm.inherited"),
            "07:00"
        )

        #expect(String(localized: afterText).contains(inheritedText))
        #expect(
            !String(localized: afterText).contains(String(localized: "change_preview.alarm.unset")))
    }

    @Test
    func testApplyInsertsData() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()

        try ShareImporter.apply(bundle: bundle, container: container)

        let context = ModelContext(container)
        let presets = try context.fetch(FetchDescriptor<ShiftPreset>())
        let patterns = try context.fetch(FetchDescriptor<RotationPattern>())
        let assignments = try context.fetch(FetchDescriptor<DayAssignment>())
        let overrides = try context.fetch(FetchDescriptor<HolidayOverride>())

        #expect(presets.count == 1)
        #expect(presets.first?.name == "Day")
        #expect(patterns.count == 1)
        #expect(patterns.first?.cycleLength == 7)
        #expect(assignments.count == 1)
        #expect(assignments.first?.overrideAlarmHour == 8)
        #expect(overrides.count == 1)
        #expect(overrides.first?.label == "Holiday")
    }

    @Test
    func testApplyAndExportPreservesCrossVacationPolicyFields() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.presets[0].crossVacationPolicy = CrossVacationPolicy.continue.rawValue
        bundle.patterns[0].crossVacationPolicy = CrossVacationPolicy.resetToDay.rawValue
        bundle.patterns[0].dayStartSlotIndex = 2

        try ShareImporter.apply(bundle: bundle, container: container)

        let context = ModelContext(container)
        let preset = try #require(try context.fetch(FetchDescriptor<ShiftPreset>()).first)
        let pattern = try #require(try context.fetch(FetchDescriptor<RotationPattern>()).first)
        let exported = ShareExporter.snapshot(from: container)

        #expect(preset.crossVacationPolicy == .continue)
        #expect(pattern.crossVacationPolicy == .resetToDay)
        #expect(pattern.dayStartSlotIndex == 2)
        #expect(
            exported.presets.first?.crossVacationPolicy == CrossVacationPolicy.continue.rawValue)
        #expect(
            exported.patterns.first?.crossVacationPolicy == CrossVacationPolicy.resetToDay.rawValue)
        #expect(exported.patterns.first?.dayStartSlotIndex == 2)
    }

    @Test
    func testApplyIdempotent() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()

        try ShareImporter.apply(bundle: bundle, container: container)
        try ShareImporter.apply(bundle: bundle, container: container)

        let context = ModelContext(container)
        let presets = try context.fetch(FetchDescriptor<ShiftPreset>())
        let patterns = try context.fetch(FetchDescriptor<RotationPattern>())
        let assignments = try context.fetch(FetchDescriptor<DayAssignment>())
        let overrides = try context.fetch(FetchDescriptor<HolidayOverride>())

        #expect(presets.count == 1)
        #expect(patterns.count == 1)
        #expect(assignments.count == 1)
        #expect(overrides.count == 1)
    }
    @Test
    func testPreviewAfterApply_showsUpdated() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()

        try ShareImporter.apply(bundle: bundle, container: container)

        let preview = ShareImporter.preview(bundle: bundle, container: container)
        #expect(preview.addedPresets == 0)
        #expect(preview.updatedPresets == 1)
        #expect(preview.addedAssignments == 0)
        #expect(preview.updatedAssignments == 1)
        #expect(
            preview.changePreview.items.first {
                $0.sourcePath == "shiftalarm:assignments[0]"
            }?.changeKind == .update
        )
    }

    @Test
    func testApplySelectedItemsOnly() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()
        let preview = ShareImporter.preview(bundle: bundle, container: container)
        let presetID = try #require(
            preview.changePreview.items.first {
                $0.sourcePath == "shiftalarm:presets[0]"
            }?.id
        )

        try ShareImporter.apply(
            bundle: bundle,
            container: container,
            selectedItemIDs: [presetID]
        )

        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<ShiftPreset>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<RotationPattern>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DayAssignment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HolidayOverride>()).isEmpty)
    }

    @Test
    func testApplySelectedAssignmentIncludesNewPresetDependency() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let bundle = makeBundle()
        let preview = ShareImporter.preview(bundle: bundle, container: container)
        let assignmentID = try #require(
            preview.changePreview.items.first {
                $0.sourcePath == "shiftalarm:assignments[0]"
            }?.id
        )

        try ShareImporter.apply(
            bundle: bundle,
            container: container,
            selectedItemIDs: [assignmentID]
        )

        let context = ModelContext(container)
        let presets = try context.fetch(FetchDescriptor<ShiftPreset>())
        let assignments = try context.fetch(FetchDescriptor<DayAssignment>())

        #expect(presets.count == 1)
        #expect(assignments.count == 1)
        #expect(assignments.first?.preset?.id == bundle.presets[0].id)
        #expect(try context.fetch(FetchDescriptor<RotationPattern>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HolidayOverride>()).isEmpty)
    }

    @Test
    func testEmptyBundleHasNoChanges() {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let empty = ShiftBundle()
        let preview = ShareImporter.preview(bundle: empty, container: container)
        #expect(!preview.hasChanges)
        #expect(preview.changePreview.sections.isEmpty)
    }
}
