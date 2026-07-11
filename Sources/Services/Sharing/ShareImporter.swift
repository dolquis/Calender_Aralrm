import Foundation
import SwiftData

public struct ImportPreview: Equatable, Sendable {
    public var addedPresets: Int
    public var updatedPresets: Int
    public var addedPatterns: Int
    public var updatedPatterns: Int
    public var addedAssignments: Int
    public var updatedAssignments: Int
    public var addedOverrides: Int
    public var updatedOverrides: Int
    public var validation: ShiftBundleValidationResult
    public var changePreview: ChangePreview

    public init(
        addedPresets: Int,
        updatedPresets: Int,
        addedPatterns: Int,
        updatedPatterns: Int,
        addedAssignments: Int,
        updatedAssignments: Int,
        addedOverrides: Int,
        updatedOverrides: Int,
        validation: ShiftBundleValidationResult = .valid,
        changePreview: ChangePreview = ChangePreview(sections: [])
    ) {
        self.addedPresets = addedPresets
        self.updatedPresets = updatedPresets
        self.addedPatterns = addedPatterns
        self.updatedPatterns = updatedPatterns
        self.addedAssignments = addedAssignments
        self.updatedAssignments = updatedAssignments
        self.addedOverrides = addedOverrides
        self.updatedOverrides = updatedOverrides
        self.validation = validation
        self.changePreview = changePreview
    }

    public var hasChanges: Bool {
        addedPresets + updatedPresets + addedPatterns + updatedPatterns + addedAssignments
            + updatedAssignments + addedOverrides + updatedOverrides > 0
    }

    public var canApply: Bool {
        canApply(selectedItemIDs: changePreview.selectedItemIDs)
    }

    public func canApply(selectedItemIDs: Set<UUID>) -> Bool {
        hasChanges && validation.isValid && changePreview.hasSelectedChanges(selectedItemIDs)
    }
}

@MainActor
public enum ShareImporter {
    public static func preview(
        bundle: ShiftBundle, container: ModelContainer, calendar: Calendar = .current
    ) -> ImportPreview {
        let validation = ShiftBundleValidator.validate(bundle)
        let context = ModelContext(container)
        let existingPresets: [UUID: ShiftPreset] =
            ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let existingPatterns: [UUID: RotationPattern] =
            ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        let existingAssignments: [Date: DayAssignment] =
            ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        let existingOverrides: [Date: HolidayOverride] =
            ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }

        let presetReferences = presetReferenceMap(bundle: bundle, existingPresets: existingPresets)
        var consumedWarningIDs = Set<UUID>()
        var addedPresets = 0
        var updatedPresets = 0
        var addedPatterns = 0
        var updatedPatterns = 0
        var addedAssignments = 0
        var updatedAssignments = 0
        var addedOverrides = 0
        var updatedOverrides = 0

        let presetItems = bundle.presets.enumerated().map { index, preset in
            let existing = existingPresets[preset.id]
            let changeKind: ChangeKind = existing == nil ? .add : .update
            if existing == nil {
                addedPresets += 1
            } else {
                updatedPresets += 1
            }
            let path = "presets[\(index)]"
            return ChangePreviewItem(
                sourcePath: sourcePath(path),
                entityKind: .preset,
                entityID: existing?.id,
                changeKind: changeKind,
                beforeText: existing.map { resource(presetSummary($0)) },
                afterText: resource(presetSummary(preset)),
                warnings: warnings(
                    for: path,
                    in: validation,
                    consumedWarningIDs: &consumedWarningIDs
                )
            )
        }

        let patternItems = bundle.patterns.enumerated().map { index, pattern in
            let existing = existingPatterns[pattern.id]
            let changeKind: ChangeKind = existing == nil ? .add : .update
            if existing == nil {
                addedPatterns += 1
            } else {
                updatedPatterns += 1
            }
            let path = "patterns[\(index)]"
            return ChangePreviewItem(
                sourcePath: sourcePath(path),
                date: pattern.anchorDate.date(in: calendar),
                entityKind: .rotationPattern,
                entityID: existing?.id,
                changeKind: changeKind,
                beforeText: existing.map { resource(rotationSummary($0, calendar: calendar)) },
                afterText: resource(rotationSummary(pattern)),
                warnings: warnings(
                    for: path,
                    in: validation,
                    consumedWarningIDs: &consumedWarningIDs
                )
            )
        }

        let assignmentItems: [ChangePreviewItem] = bundle.assignments.enumerated().compactMap {
            (index, assignment) -> ChangePreviewItem? in
            guard let day = assignment.date.date(in: calendar) else { return nil }
            let existing = existingAssignments[day]
            let changeKind: ChangeKind = existing == nil ? .add : .update
            if existing == nil {
                addedAssignments += 1
            } else {
                updatedAssignments += 1
            }
            let path = "assignments[\(index)]"
            return ChangePreviewItem(
                sourcePath: sourcePath(path),
                date: day,
                entityKind: .dayAssignment,
                entityID: existing?.id,
                changeKind: changeKind,
                beforeText: existing.map { resource(assignmentSummary($0, calendar: calendar)) },
                afterText: resource(
                    assignmentSummary(assignment, presetReferences: presetReferences)),
                warnings: warnings(
                    for: path,
                    in: validation,
                    consumedWarningIDs: &consumedWarningIDs
                )
            )
        }

        let overrideItems: [ChangePreviewItem] = bundle.overrides.enumerated().compactMap {
            (index, override) -> ChangePreviewItem? in
            guard let day = override.date.date(in: calendar) else { return nil }
            let existing = existingOverrides[day]
            let changeKind: ChangeKind = existing == nil ? .add : .update
            if existing == nil {
                addedOverrides += 1
            } else {
                updatedOverrides += 1
            }
            let path = "overrides[\(index)]"
            return ChangePreviewItem(
                sourcePath: sourcePath(path),
                date: day,
                entityKind: .holidayOverride,
                entityID: existing?.id,
                changeKind: changeKind,
                beforeText: existing.map { resource(overrideSummary($0, calendar: calendar)) },
                afterText: resource(overrideSummary(override, presetReferences: presetReferences)),
                warnings: warnings(
                    for: path,
                    in: validation,
                    consumedWarningIDs: &consumedWarningIDs
                )
            )
        }

        var sections: [ChangePreviewSection] = []
        appendSection(
            sourcePath: "shiftalarm:presets",
            title: String(localized: "change_preview.section.presets"),
            items: presetItems,
            sections: &sections
        )
        appendSection(
            sourcePath: "shiftalarm:patterns",
            title: String(localized: "change_preview.section.rotations"),
            items: patternItems,
            sections: &sections
        )
        appendSection(
            sourcePath: "shiftalarm:assignments",
            title: String(localized: "change_preview.section.assignments"),
            items: assignmentItems,
            sections: &sections
        )
        appendSection(
            sourcePath: "shiftalarm:overrides",
            title: String(localized: "change_preview.section.overrides"),
            items: overrideItems,
            sections: &sections
        )
        appendSection(
            sourcePath: "shiftalarm:validation",
            title: String(localized: "change_preview.section.validation"),
            items: validationItems(
                validation,
                consumedWarningIDs: consumedWarningIDs
            ),
            sections: &sections
        )

        let changePreview = ChangePreview(sections: sections)
        return ImportPreview(
            addedPresets: addedPresets,
            updatedPresets: updatedPresets,
            addedPatterns: addedPatterns,
            updatedPatterns: updatedPatterns,
            addedAssignments: addedAssignments,
            updatedAssignments: updatedAssignments,
            addedOverrides: addedOverrides,
            updatedOverrides: updatedOverrides,
            validation: validation,
            changePreview: changePreview
        )
    }

    public static func apply(
        bundle: ShiftBundle,
        container: ModelContainer,
        calendar: Calendar = .current,
        selectedItemIDs: Set<UUID>? = nil
    ) throws {
        let validation = ShiftBundleValidator.validate(bundle)
        guard validation.isValid else {
            throw ShiftBundleValidationError(result: validation)
        }
        let bundleToApply: ShiftBundle
        if let selectedItemIDs {
            let filtered = filteredBundle(
                bundle: bundle,
                selectedItemIDs: selectedItemIDs,
                container: container,
                calendar: calendar
            )
            guard
                !filtered.presets.isEmpty || !filtered.patterns.isEmpty
                    || !filtered.assignments.isEmpty || !filtered.overrides.isEmpty
            else {
                return
            }
            bundleToApply = filtered
        } else {
            bundleToApply = bundle
        }

        let context = ModelContext(container)
        let presets = applyPresets(bundleToApply.presets, context: context)
        applyPatterns(bundleToApply.patterns, context: context, calendar: calendar)
        applyAssignments(
            bundleToApply.assignments, presets: presets, context: context, calendar: calendar)
        applyOverrides(
            bundleToApply.overrides, presets: presets, context: context, calendar: calendar)
        try context.save()
    }

    // MARK: - Apply helpers

    private static func applyPresets(
        _ presets: [ShiftBundle.PresetDTO], context: ModelContext
    ) -> [UUID: ShiftPreset] {
        var byID: [UUID: ShiftPreset] = ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        for p in presets {
            let colorHex = ShiftBundleValidator.normalizedColorHex(p.colorHex)
            let crossVacationPolicy = crossVacationPolicy(from: p.crossVacationPolicy)
            if let existing = byID[p.id] {
                existing.name = p.name
                existing.colorHex = colorHex
                existing.defaultAlarmHour = p.defaultAlarmHour
                existing.defaultAlarmMinute = p.defaultAlarmMinute
                existing.soundID = p.soundID
                existing.note = p.note
                existing.crossVacationPolicyRaw = crossVacationPolicy?.rawValue
            } else {
                let new = ShiftPreset(
                    id: p.id,
                    name: p.name,
                    colorHex: colorHex,
                    defaultAlarmHour: p.defaultAlarmHour,
                    defaultAlarmMinute: p.defaultAlarmMinute,
                    soundID: p.soundID,
                    note: p.note,
                    crossVacationPolicy: crossVacationPolicy
                )
                context.insert(new)
                byID[p.id] = new
            }
        }
        return byID
    }

    private static func applyPatterns(
        _ patterns: [ShiftBundle.RotationDTO], context: ModelContext, calendar: Calendar
    ) {
        var byID: [UUID: RotationPattern] =
            ((try? context.fetch(FetchDescriptor<RotationPattern>())) ?? [])
            .reduce(into: [:]) { $0[$1.id] = $1 }
        for r in patterns {
            guard let anchor = r.anchorDate.date(in: calendar) else { continue }
            let start = r.startDate?.date(in: calendar)
            let end = r.endDate?.date(in: calendar)
            let crossVacationPolicy =
                crossVacationPolicy(from: r.crossVacationPolicy) ?? .invert
            if let existing = byID[r.id] {
                existing.name = r.name
                existing.anchorDate = anchor
                existing.cycleLength = r.cycleLength
                existing.slots = r.slots
                existing.startDate = start
                existing.endDate = end
                existing.priority = r.priority
                existing.isActive = r.isActive
                existing.crossVacationPolicyRaw = crossVacationPolicy.rawValue
                existing.dayStartSlotIndex = r.dayStartSlotIndex
            } else {
                let new = RotationPattern(
                    id: r.id,
                    name: r.name,
                    anchorDate: anchor,
                    cycleLength: r.cycleLength,
                    slots: r.slots,
                    startDate: start,
                    endDate: end,
                    priority: r.priority,
                    isActive: r.isActive,
                    crossVacationPolicy: crossVacationPolicy,
                    dayStartSlotIndex: r.dayStartSlotIndex
                )
                context.insert(new)
                byID[r.id] = new
            }
        }
    }

    private static func crossVacationPolicy(from rawValue: Int?) -> CrossVacationPolicy? {
        rawValue.flatMap(CrossVacationPolicy.init(rawValue:))
    }

    private static func applyAssignments(
        _ assignments: [ShiftBundle.AssignmentDTO],
        presets: [UUID: ShiftPreset],
        context: ModelContext,
        calendar: Calendar
    ) {
        var byDay: [Date: DayAssignment] =
            ((try? context.fetch(FetchDescriptor<DayAssignment>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        var seen = Set(byDay.keys)
        for a in assignments {
            guard let day = a.date.date(in: calendar) else { continue }
            let preset = a.presetID.flatMap { presets[$0] }
            if let existing = byDay[day] {
                existing.preset = preset
                existing.overrideAlarmHour = a.overrideAlarmHour
                existing.overrideAlarmMinute = a.overrideAlarmMinute
                existing.skipAlarm = a.skipAlarm
                existing.note = a.note
            } else if !seen.contains(day) {
                seen.insert(day)
                let new = DayAssignment(
                    date: day,
                    preset: preset,
                    overrideAlarmHour: a.overrideAlarmHour,
                    overrideAlarmMinute: a.overrideAlarmMinute,
                    skipAlarm: a.skipAlarm,
                    note: a.note
                )
                context.insert(new)
                byDay[day] = new
            }
        }
    }

    private static func applyOverrides(
        _ overrides: [ShiftBundle.OverrideDTO],
        presets: [UUID: ShiftPreset],
        context: ModelContext,
        calendar: Calendar
    ) {
        var byDay: [Date: HolidayOverride] =
            ((try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? [])
            .reduce(into: [:]) { $0[calendar.startOfDay(for: $1.date)] = $1 }
        var seen = Set(byDay.keys)
        for o in overrides {
            guard let day = o.date.date(in: calendar) else { continue }
            let replacement = o.replacementPresetID.flatMap { presets[$0] }
            // Concretize the incoming behavior. The recipient has no access to the sender's
            // device-local default, so `inherit` (only possible from a third-party or
            // hand-edited bundle) is coerced to `.silence` to avoid a surprise ring. Legacy
            // bundles (no `alarmBehavior`) preserve the sender's explicit intent via
            // `skipAlarm`: `true → silence`, `false → ring`.
            let behavior: HolidayAlarmBehavior
            if let declared = o.alarmBehavior {
                behavior = (declared == .inherit) ? .silence : declared
            } else {
                behavior = o.skipAlarm ? .silence : .ring
            }
            if let existing = byDay[day] {
                existing.kind = o.kind
                existing.label = o.label
                existing.alarmBehavior = behavior  // setter also syncs `skipAlarm`
                existing.replacementPreset = replacement
            } else if !seen.contains(day) {
                seen.insert(day)
                let new = HolidayOverride(
                    date: day,
                    kind: o.kind,
                    label: o.label,
                    skipAlarm: behavior == .silence,
                    alarmBehaviorRaw: behavior.rawValue,
                    replacementPreset: replacement
                )
                context.insert(new)
                byDay[day] = new
            }
        }
    }

    // MARK: - Preview helpers

    private static func appendSection(
        sourcePath: String,
        title: String,
        items: [ChangePreviewItem],
        sections: inout [ChangePreviewSection]
    ) {
        guard !items.isEmpty else { return }
        sections.append(ChangePreviewSection(sourcePath: sourcePath, title: title, items: items))
    }

    private static func sourcePath(_ path: String) -> String {
        "shiftalarm:\(path)"
    }

    private static func resource(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: text)
    }

    private static func warnings(
        for path: String,
        in validation: ShiftBundleValidationResult,
        consumedWarningIDs: inout Set<UUID>
    ) -> [LocalizedStringResource] {
        validation.warnings.compactMap { issue in
            guard issue.path == path || issue.path.hasPrefix("\(path).") else { return nil }
            consumedWarningIDs.insert(issue.id)
            return resource(issue.message)
        }
    }

    private static func validationItems(
        _ validation: ShiftBundleValidationResult,
        consumedWarningIDs: Set<UUID>
    ) -> [ChangePreviewItem] {
        let errors = validation.errors.map { issue in
            ChangePreviewItem(
                sourcePath: sourcePath(issue.path),
                entityKind: entityKind(for: issue.path),
                changeKind: .conflict,
                afterText: resource(issue.message),
                warnings: []
            )
        }
        let warnings = validation.warnings
            .filter { !consumedWarningIDs.contains($0.id) }
            .map { issue in
                ChangePreviewItem(
                    sourcePath: sourcePath(issue.path),
                    entityKind: entityKind(for: issue.path),
                    changeKind: .unchanged,
                    afterText: resource(issue.message),
                    warnings: [resource(issue.message)]
                )
            }
        return errors + warnings
    }

    private static func entityKind(for path: String) -> ChangeEntityKind {
        if path.hasPrefix("presets") {
            return .preset
        } else if path.hasPrefix("patterns") {
            return .rotationPattern
        } else if path.hasPrefix("assignments") {
            return .dayAssignment
        } else if path.hasPrefix("overrides") {
            return .holidayOverride
        }
        return .preset
    }

    private struct PresetPreviewReference {
        var name: String
        var defaultAlarmHour: Int?
        var defaultAlarmMinute: Int?
    }

    private static func presetReferenceMap(
        bundle: ShiftBundle,
        existingPresets: [UUID: ShiftPreset]
    ) -> [UUID: PresetPreviewReference] {
        var references = existingPresets.mapValues {
            PresetPreviewReference(
                name: $0.name,
                defaultAlarmHour: $0.defaultAlarmHour,
                defaultAlarmMinute: $0.defaultAlarmMinute
            )
        }
        for preset in bundle.presets {
            references[preset.id] = PresetPreviewReference(
                name: preset.name,
                defaultAlarmHour: preset.defaultAlarmHour,
                defaultAlarmMinute: preset.defaultAlarmMinute
            )
        }
        return references
    }

    private static func presetSummary(_ preset: ShiftPreset) -> String {
        String(
            format: String(localized: "change_preview.preset.summary"),
            preset.name,
            alarmText(hour: preset.defaultAlarmHour, minute: preset.defaultAlarmMinute)
        )
    }

    private static func presetSummary(_ preset: ShiftBundle.PresetDTO) -> String {
        String(
            format: String(localized: "change_preview.preset.summary"),
            preset.name,
            alarmText(hour: preset.defaultAlarmHour, minute: preset.defaultAlarmMinute)
        )
    }

    private static func rotationSummary(
        _ pattern: RotationPattern,
        calendar: Calendar
    ) -> String {
        let state =
            pattern.isActive
            ? String(localized: "change_preview.rotation.active")
            : String(localized: "change_preview.rotation.inactive")
        return String(
            format: String(localized: "change_preview.rotation.summary"),
            pattern.name,
            pattern.cycleLength,
            dateText(pattern.anchorDate, calendar: calendar),
            state
        )
    }

    private static func rotationSummary(_ pattern: ShiftBundle.RotationDTO) -> String {
        let state =
            pattern.isActive
            ? String(localized: "change_preview.rotation.active")
            : String(localized: "change_preview.rotation.inactive")
        return String(
            format: String(localized: "change_preview.rotation.summary"),
            pattern.name,
            pattern.cycleLength,
            calendarDayText(pattern.anchorDate),
            state
        )
    }

    private static func assignmentSummary(
        _ assignment: DayAssignment,
        calendar: Calendar
    ) -> String {
        String(
            format: String(localized: "change_preview.assignment.summary"),
            dateText(assignment.date, calendar: calendar),
            assignment.preset?.name ?? String(localized: "change_preview.assignment.rest_day"),
            assignmentAlarmText(
                overrideHour: assignment.overrideAlarmHour,
                overrideMinute: assignment.overrideAlarmMinute,
                inheritedHour: assignment.preset?.defaultAlarmHour,
                inheritedMinute: assignment.preset?.defaultAlarmMinute,
                skipAlarm: assignment.skipAlarm
            )
        )
    }

    private static func assignmentSummary(
        _ assignment: ShiftBundle.AssignmentDTO,
        presetReferences: [UUID: PresetPreviewReference]
    ) -> String {
        let preset = assignment.presetID.flatMap { presetReferences[$0] }
        return String(
            format: String(localized: "change_preview.assignment.summary"),
            calendarDayText(assignment.date),
            preset?.name ?? String(localized: "change_preview.assignment.rest_day"),
            assignmentAlarmText(
                overrideHour: assignment.overrideAlarmHour,
                overrideMinute: assignment.overrideAlarmMinute,
                inheritedHour: preset?.defaultAlarmHour,
                inheritedMinute: preset?.defaultAlarmMinute,
                skipAlarm: assignment.skipAlarm
            )
        )
    }

    private static func overrideSummary(
        _ override: HolidayOverride,
        calendar: Calendar
    ) -> String {
        String(
            format: String(localized: "change_preview.override.summary"),
            dateText(override.date, calendar: calendar),
            override.label,
            overrideActionText(
                skipAlarm: override.skipAlarm,
                replacementName: override.replacementPreset?.name
            )
        )
    }

    private static func overrideSummary(
        _ override: ShiftBundle.OverrideDTO,
        presetReferences: [UUID: PresetPreviewReference]
    ) -> String {
        String(
            format: String(localized: "change_preview.override.summary"),
            calendarDayText(override.date),
            override.label,
            overrideActionText(
                skipAlarm: override.skipAlarm,
                replacementName: override.replacementPresetID.flatMap { presetReferences[$0]?.name }
            )
        )
    }

    private static func assignmentAlarmText(
        overrideHour: Int?,
        overrideMinute: Int?,
        inheritedHour: Int?,
        inheritedMinute: Int?,
        skipAlarm: Bool
    ) -> String {
        if skipAlarm {
            return String(localized: "change_preview.alarm.skipped")
        }
        if let overrideHour, let overrideMinute {
            return alarmText(hour: overrideHour, minute: overrideMinute)
        }
        guard let inheritedHour, let inheritedMinute else {
            return String(localized: "change_preview.alarm.unset")
        }
        return String(
            format: String(localized: "change_preview.alarm.inherited"),
            alarmText(hour: inheritedHour, minute: inheritedMinute)
        )
    }

    private static func alarmText(
        hour: Int?,
        minute: Int?,
        skipAlarm: Bool = false
    ) -> String {
        if skipAlarm {
            return String(localized: "change_preview.alarm.skipped")
        }
        guard let hour, let minute else {
            return String(localized: "change_preview.alarm.unset")
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func overrideActionText(
        skipAlarm: Bool,
        replacementName: String?
    ) -> String {
        if skipAlarm {
            return String(localized: "change_preview.alarm.skipped")
        }
        guard let replacementName else {
            return String(localized: "change_preview.alarm.unset")
        }
        return String(
            format: String(localized: "change_preview.override.replacement"),
            replacementName
        )
    }

    private static func dateText(_ date: Date, calendar: Calendar) -> String {
        guard let day = CalendarDay(date: date, calendar: calendar) else { return "" }
        return calendarDayText(day)
    }

    private static func calendarDayText(_ day: CalendarDay) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    private static func filteredBundle(
        bundle: ShiftBundle,
        selectedItemIDs: Set<UUID>,
        container: ModelContainer,
        calendar: Calendar
    ) -> ShiftBundle {
        let currentPreview = preview(bundle: bundle, container: container, calendar: calendar)
        let selectableIDs = currentPreview.changePreview.selectableItemIDs
        let selectedIDs = selectedItemIDs.intersection(selectableIDs)
        let selectedSourcePaths = Set(
            currentPreview.changePreview.items
                .filter { selectedIDs.contains($0.id) }
                .map(\.sourcePath)
        )
        guard !selectedSourcePaths.isEmpty else {
            return ShiftBundle(version: bundle.version, exportedAt: bundle.exportedAt)
        }

        let context = ModelContext(container)
        let existingPresetIDs = Set(
            ((try? context.fetch(FetchDescriptor<ShiftPreset>())) ?? []).map(\.id)
        )

        let patterns = bundle.patterns.enumerated().compactMap { index, pattern in
            selectedSourcePaths.contains(sourcePath("patterns[\(index)]")) ? pattern : nil
        }
        let assignments = bundle.assignments.enumerated().compactMap { index, assignment in
            selectedSourcePaths.contains(sourcePath("assignments[\(index)]")) ? assignment : nil
        }
        let overrides = bundle.overrides.enumerated().compactMap { index, override in
            selectedSourcePaths.contains(sourcePath("overrides[\(index)]")) ? override : nil
        }

        var requiredNewPresetIDs = Set<UUID>()
        requiredNewPresetIDs.formUnion(patterns.flatMap { $0.slots.compactMap { $0 } })
        requiredNewPresetIDs.formUnion(assignments.compactMap(\.presetID))
        requiredNewPresetIDs.formUnion(overrides.compactMap(\.replacementPresetID))
        requiredNewPresetIDs.subtract(existingPresetIDs)

        let presets = bundle.presets.enumerated().compactMap { index, preset in
            let isExplicitlySelected = selectedSourcePaths.contains(sourcePath("presets[\(index)]"))
            return isExplicitlySelected || requiredNewPresetIDs.contains(preset.id) ? preset : nil
        }

        return ShiftBundle(
            version: bundle.version,
            exportedAt: bundle.exportedAt,
            presets: presets,
            patterns: patterns,
            assignments: assignments,
            overrides: overrides
        )
    }
}
