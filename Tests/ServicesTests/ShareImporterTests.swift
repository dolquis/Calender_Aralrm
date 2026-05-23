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
    }
    @Test
    func testEmptyBundleHasNoChanges() {
        let container = SharedPersistence.makeContainer(inMemory: true)
        let empty = ShiftBundle()
        let preview = ShareImporter.preview(bundle: empty, container: container)
        #expect(!preview.hasChanges)
    }
}
