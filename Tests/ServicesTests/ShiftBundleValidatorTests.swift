import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
struct ShiftBundleValidatorTests {
    private static let presetID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let missingPresetID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!

    @Test
    func sbvU1_validBundleIsValid() {
        let result = ShiftBundleValidator.validate(makeBundle())

        #expect(result == .valid)
    }

    @Test
    func sbvU2_unsupportedVersionIsError() {
        var bundle = makeBundle()
        bundle.version = 0

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .unsupportedVersion, path: "version"))
    }

    @Test
    func sbvU3_invalidPresetDefaultHourIsError() {
        var bundle = makeBundle()
        bundle.presets[0].defaultAlarmHour = 24

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .invalidAlarmHour, path: "presets[0].defaultAlarmHour"))
    }

    @Test
    func sbvU4_invalidPresetDefaultMinuteIsError() {
        var bundle = makeBundle()
        bundle.presets[0].defaultAlarmMinute = 60

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .invalidAlarmMinute, path: "presets[0].defaultAlarmMinute"))
    }

    @Test
    func sbvU5_slotCountMismatchIsError() {
        var bundle = makeBundle()
        bundle.patterns[0].cycleLength = 3

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .slotCountMismatch, path: "patterns[0].slots"))
    }

    @Test
    func sbvU6_duplicateUUIDIsError() {
        var bundle = makeBundle()
        bundle.presets.append(bundle.presets[0])

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .duplicateID, path: "presets[1].id"))
    }

    @Test
    func sbvU7_missingAssignmentPresetReferenceSeverityFollowsFireability() {
        var errorBundle = makeBundle()
        errorBundle.assignments[0].presetID = Self.missingPresetID
        errorBundle.assignments[0].overrideAlarmHour = nil
        errorBundle.assignments[0].overrideAlarmMinute = nil
        errorBundle.assignments[0].skipAlarm = false

        var warningBundle = makeBundle()
        warningBundle.assignments[0].presetID = Self.missingPresetID
        warningBundle.assignments[0].skipAlarm = true

        var customTimeBundle = makeBundle()
        customTimeBundle.assignments[0].presetID = nil
        customTimeBundle.assignments[0].overrideAlarmHour = 6
        customTimeBundle.assignments[0].overrideAlarmMinute = 45
        customTimeBundle.assignments[0].skipAlarm = false

        var stalePresetCustomTimeBundle = makeBundle()
        stalePresetCustomTimeBundle.assignments[0].presetID = Self.missingPresetID
        stalePresetCustomTimeBundle.assignments[0].overrideAlarmHour = 6
        stalePresetCustomTimeBundle.assignments[0].overrideAlarmMinute = 45
        stalePresetCustomTimeBundle.assignments[0].skipAlarm = false

        let errorResult = ShiftBundleValidator.validate(errorBundle)
        let warningResult = ShiftBundleValidator.validate(warningBundle)
        let customTimeResult = ShiftBundleValidator.validate(customTimeBundle)
        let stalePresetCustomTimeResult = ShiftBundleValidator.validate(stalePresetCustomTimeBundle)

        #expect(hasError(errorResult, .missingPresetReference, path: "assignments[0].presetID"))
        #expect(warningResult.isValid)
        #expect(
            hasWarning(warningResult, .missingPresetReference, path: "assignments[0].presetID"))
        #expect(customTimeResult == .valid)
        #expect(stalePresetCustomTimeResult.isValid)
        #expect(
            hasWarning(
                stalePresetCustomTimeResult, .missingPresetReference,
                path: "assignments[0].presetID"))
    }

    @Test
    func sbvU8_tooManyItemsIsError() {
        var bundle = makeBundle()
        bundle.presets = (1...101).map { makePreset(id: uuid($0)) }
        bundle.patterns[0].slots = [uuid(1), uuid(1), nil, nil, nil, nil, nil]
        bundle.assignments[0].presetID = uuid(1)

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .tooManyItems, path: "presets"))
    }

    @Test
    func sbvU9_invalidAssignmentOverrideHourIsError() {
        var bundle = makeBundle()
        bundle.assignments[0].overrideAlarmHour = 24

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .invalidAlarmHour, path: "assignments[0].overrideAlarmHour"))
    }

    @Test
    func sbvU10_invalidAssignmentOverrideMinuteIsError() {
        var bundle = makeBundle()
        bundle.assignments[0].overrideAlarmMinute = 60

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .invalidAlarmMinute, path: "assignments[0].overrideAlarmMinute"))
    }

    @Test
    func sbvU11_duplicateAssignmentDateIsError() {
        var bundle = makeBundle()
        bundle.assignments.append(bundle.assignments[0])
        bundle.overrides.append(bundle.overrides[0])

        let result = ShiftBundleValidator.validate(bundle)

        #expect(hasError(result, .duplicateDate, path: "assignments[1].date"))
        #expect(hasError(result, .duplicateDate, path: "overrides[1].date"))
    }

    @Test
    func sbvU12_missingOverridePresetReferenceWithAlarmIsError() {
        var bundle = makeBundle()
        bundle.overrides[0].skipAlarm = false
        bundle.overrides[0].replacementPresetID = Self.missingPresetID

        let result = ShiftBundleValidator.validate(bundle)

        #expect(
            hasError(result, .missingPresetReference, path: "overrides[0].replacementPresetID"))
    }

    @Test
    func sbvU13_missingOverridePresetReferenceWithSkipAlarmIsWarning() {
        var bundle = makeBundle()
        bundle.overrides[0].skipAlarm = true
        bundle.overrides[0].replacementPresetID = Self.missingPresetID

        let result = ShiftBundleValidator.validate(bundle)

        #expect(result.isValid)
        #expect(
            hasWarning(result, .missingPresetReference, path: "overrides[0].replacementPresetID"))
    }

    @Test
    func sbvU14_missingPatternSlotPresetReferenceIsWarning() {
        var bundle = makeBundle()
        bundle.patterns[0].slots[0] = Self.missingPresetID

        let result = ShiftBundleValidator.validate(bundle)

        #expect(result.isValid)
        #expect(hasWarning(result, .missingPresetReference, path: "patterns[0].slots[0]"))
    }

    @Test
    func sbvU15_invalidVacationPolicyFieldsAreErrors() {
        var bundle = makeBundle()
        bundle.presets[0].crossVacationPolicy = 999
        bundle.patterns[0].crossVacationPolicy = -1
        bundle.patterns[0].dayStartSlotIndex = bundle.patterns[0].cycleLength

        let result = ShiftBundleValidator.validate(bundle)

        #expect(
            hasError(
                result, .invalidCrossVacationPolicy,
                path: "presets[0].crossVacationPolicy"))
        #expect(
            hasError(
                result, .invalidCrossVacationPolicy,
                path: "patterns[0].crossVacationPolicy"))
        #expect(
            hasError(
                result, .invalidDayStartSlotIndex,
                path: "patterns[0].dayStartSlotIndex"))
    }

    @Test
    func validatorIssueIDIsDeterministic() {
        var bundle = makeBundle()
        bundle.presets[0].defaultAlarmHour = 24

        let first = ShiftBundleValidator.validate(bundle)
        let second = ShiftBundleValidator.validate(bundle)

        #expect(first.errors.first?.id == second.errors.first?.id)
    }

    @Test
    func sbvI1_previewIncludesValidationBeforeApply() {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.presets[0].defaultAlarmHour = 24

        let preview = ShareImporter.preview(bundle: bundle, container: container)

        #expect(
            hasError(preview.validation, .invalidAlarmHour, path: "presets[0].defaultAlarmHour"))
        #expect(preview.addedPresets == 1)
    }

    @Test
    func sbvI2_invalidPreviewCannotApplyAndApplyThrows() {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.assignments[0].presetID = Self.missingPresetID
        bundle.assignments[0].overrideAlarmHour = nil
        bundle.assignments[0].overrideAlarmMinute = nil

        let preview = ShareImporter.preview(bundle: bundle, container: container)

        #expect(preview.hasChanges)
        #expect(!preview.canApply)
        #expect(throws: ShiftBundleValidationError.self) {
            try ShareImporter.apply(bundle: bundle, container: container)
        }
    }

    @Test
    func warningOnlyInvalidColorHexAppliesDefaultColor() throws {
        let container = SharedPersistence.makeContainer(inMemory: true)
        var bundle = makeBundle()
        bundle.presets[0].colorHex = "zzzzzz"

        let preview = ShareImporter.preview(bundle: bundle, container: container)
        try ShareImporter.apply(bundle: bundle, container: container)

        let context = ModelContext(container)
        let presets = try context.fetch(FetchDescriptor<ShiftPreset>())

        #expect(preview.canApply)
        #expect(hasWarning(preview.validation, .invalidColorHex, path: "presets[0].colorHex"))
        #expect(presets.first?.colorHex == ShiftBundleValidator.fallbackColorHex)
    }

    private func makeBundle() -> ShiftBundle {
        ShiftBundle(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            presets: [makePreset(id: Self.presetID)],
            patterns: [
                ShiftBundle.RotationDTO(
                    id: uuid(10),
                    name: "5on2off",
                    anchorDate: CalendarDay(year: 2026, month: 5, day: 1),
                    cycleLength: 7,
                    slots: [
                        Self.presetID, Self.presetID, Self.presetID, Self.presetID, Self.presetID,
                        nil, nil,
                    ],
                    startDate: nil,
                    endDate: nil,
                    priority: 0,
                    isActive: true
                )
            ],
            assignments: [
                ShiftBundle.AssignmentDTO(
                    date: CalendarDay(year: 2026, month: 5, day: 1),
                    presetID: Self.presetID,
                    overrideAlarmHour: 8,
                    overrideAlarmMinute: 30,
                    skipAlarm: false,
                    note: "early"
                )
            ],
            overrides: [
                ShiftBundle.OverrideDTO(
                    date: CalendarDay(year: 2026, month: 5, day: 2),
                    kind: .publicHoliday,
                    label: "Holiday",
                    skipAlarm: true,
                    replacementPresetID: nil
                )
            ]
        )
    }

    private func makePreset(id: UUID) -> ShiftBundle.PresetDTO {
        ShiftBundle.PresetDTO(
            id: id,
            name: "Day",
            colorHex: "#1E88E5",
            defaultAlarmHour: 7,
            defaultAlarmMinute: 0,
            soundID: AlarmSound.systemDefault.id,
            note: ""
        )
    }

    private func hasError(
        _ result: ShiftBundleValidationResult,
        _ code: ShiftBundleValidationCode,
        path: String
    ) -> Bool {
        result.errors.contains { $0.code == code && $0.path == path }
    }

    private func hasWarning(
        _ result: ShiftBundleValidationResult,
        _ code: ShiftBundleValidationCode,
        path: String
    ) -> Bool {
        result.warnings.contains { $0.code == code && $0.path == path }
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
