import CryptoKit
import Foundation

public struct ShiftBundleValidationResult: Equatable, Sendable {
    public static let valid = ShiftBundleValidationResult()

    public var errors: [ShiftBundleValidationIssue]
    public var warnings: [ShiftBundleValidationIssue]

    public var isValid: Bool { errors.isEmpty }
    public var hasIssues: Bool { !errors.isEmpty || !warnings.isEmpty }

    public init(
        errors: [ShiftBundleValidationIssue] = [],
        warnings: [ShiftBundleValidationIssue] = []
    ) {
        self.errors = errors
        self.warnings = warnings
    }
}

public struct ShiftBundleValidationIssue: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var code: ShiftBundleValidationCode
    public var path: String
    public var message: String

    public init(code: ShiftBundleValidationCode, path: String, message: String) {
        self.id = Self.deterministicID(code: code, path: path)
        self.code = code
        self.path = path
        self.message = message
    }

    private static func deterministicID(code: ShiftBundleValidationCode, path: String) -> UUID {
        let raw = "\(code.rawValue)|\(path)"
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

public enum ShiftBundleValidationCode: String, Sendable {
    case unsupportedVersion
    case futureVersion
    case tooManyItems
    case invalidAlarmHour
    case invalidAlarmMinute
    case invalidCycleLength
    case slotCountMismatch
    case duplicateID
    case duplicateDate
    case missingPresetReference
    case textTooLong
    case invalidColorHex
    case invalidCrossVacationPolicy
    case invalidDayStartSlotIndex
    /// A `.shiftalarm` override declares `alarmBehavior: inherit`, which a canonical exporter
    /// never writes. The importer coerces it to `silence`; surfaced as a warning (P2-ζ).
    case holidayBehaviorInherit
}

public struct ShiftBundleValidationError: Error, LocalizedError, Equatable, Sendable {
    public var result: ShiftBundleValidationResult

    public var errorDescription: String? {
        guard let first = result.errors.first else {
            return String(localized: "import.validation.apply_error")
        }
        return "\(String(localized: "import.validation.apply_error")) \(first.message)"
    }

    public init(result: ShiftBundleValidationResult) {
        self.result = result
    }
}

public enum ShiftBundleValidator {
    public static let fallbackColorHex = "#1E88E5"
    public static let supportedVersion = 1

    public static func normalizedColorHex(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValidColorHex(text) ? text : fallbackColorHex
    }

    private enum Limits {
        static let presets = 100
        static let assignments = 2_000
        static let patterns = 50
        static let overrides = 3_000
        static let presetNameLength = 64
        static let noteLength = 512
        static let cycleLength = 365
    }

    public static func validate(_ bundle: ShiftBundle) -> ShiftBundleValidationResult {
        var errors: [ShiftBundleValidationIssue] = []
        var warnings: [ShiftBundleValidationIssue] = []
        let presetIDs = Set(bundle.presets.map(\.id))

        func addError(_ code: ShiftBundleValidationCode, path: String) {
            errors.append(issue(code, path: path))
        }

        func addWarning(_ code: ShiftBundleValidationCode, path: String) {
            warnings.append(issue(code, path: path))
        }

        if bundle.version < 1 {
            addError(.unsupportedVersion, path: "version")
        } else if bundle.version > supportedVersion {
            addError(.futureVersion, path: "version")
        }

        checkLimit(bundle.presets.count, max: Limits.presets, path: "presets", errors: &errors)
        checkLimit(
            bundle.assignments.count, max: Limits.assignments, path: "assignments",
            errors: &errors)
        checkLimit(bundle.patterns.count, max: Limits.patterns, path: "patterns", errors: &errors)
        checkLimit(
            bundle.overrides.count, max: Limits.overrides, path: "overrides", errors: &errors)

        checkDuplicateIDs(
            bundle.presets.enumerated().map {
                (id: $0.element.id, path: "presets[\($0.offset)].id")
            },
            errors: &errors)
        checkDuplicateIDs(
            bundle.patterns.enumerated().map {
                (id: $0.element.id, path: "patterns[\($0.offset)].id")
            },
            errors: &errors)
        checkDuplicateAssignmentDates(bundle.assignments, errors: &errors)
        checkDuplicateOverrideDates(bundle.overrides, errors: &errors)

        for (index, preset) in bundle.presets.enumerated() {
            let path = "presets[\(index)]"
            if preset.name.count > Limits.presetNameLength {
                addError(.textTooLong, path: "\(path).name")
            }
            if preset.note.count > Limits.noteLength {
                addWarning(.textTooLong, path: "\(path).note")
            }
            if !isValidColorHex(preset.colorHex) {
                addWarning(.invalidColorHex, path: "\(path).colorHex")
            }
            if let hour = preset.defaultAlarmHour, !isValidHour(hour) {
                addError(.invalidAlarmHour, path: "\(path).defaultAlarmHour")
            }
            if let minute = preset.defaultAlarmMinute, !isValidMinute(minute) {
                addError(.invalidAlarmMinute, path: "\(path).defaultAlarmMinute")
            }
            if let policy = preset.crossVacationPolicy,
                CrossVacationPolicy(rawValue: policy) == nil
            {
                addError(.invalidCrossVacationPolicy, path: "\(path).crossVacationPolicy")
            }
        }

        for (index, pattern) in bundle.patterns.enumerated() {
            let path = "patterns[\(index)]"
            if pattern.cycleLength < 1 || pattern.cycleLength > Limits.cycleLength {
                addError(.invalidCycleLength, path: "\(path).cycleLength")
            }
            if pattern.slots.count != pattern.cycleLength {
                addError(.slotCountMismatch, path: "\(path).slots")
            }
            if let policy = pattern.crossVacationPolicy,
                CrossVacationPolicy(rawValue: policy) == nil
            {
                addError(.invalidCrossVacationPolicy, path: "\(path).crossVacationPolicy")
            }
            if let dayStartSlotIndex = pattern.dayStartSlotIndex,
                pattern.cycleLength < 1 || dayStartSlotIndex < 0
                    || dayStartSlotIndex >= pattern.cycleLength
            {
                addError(.invalidDayStartSlotIndex, path: "\(path).dayStartSlotIndex")
            }
            for (slotIndex, presetID) in pattern.slots.enumerated() {
                guard let presetID, !presetIDs.contains(presetID) else { continue }
                addWarning(.missingPresetReference, path: "\(path).slots[\(slotIndex)]")
            }
        }

        for (index, assignment) in bundle.assignments.enumerated() {
            let path = "assignments[\(index)]"
            if let hour = assignment.overrideAlarmHour, !isValidHour(hour) {
                addError(.invalidAlarmHour, path: "\(path).overrideAlarmHour")
            }
            if let minute = assignment.overrideAlarmMinute, !isValidMinute(minute) {
                addError(.invalidAlarmMinute, path: "\(path).overrideAlarmMinute")
            }
            if assignment.note.count > Limits.noteLength {
                addWarning(.textTooLong, path: "\(path).note")
            }
            if let presetID = assignment.presetID {
                if !presetIDs.contains(presetID) {
                    let target = "\(path).presetID"
                    assignment.skipAlarm || hasCompleteOverrideTime(assignment)
                        ? addWarning(.missingPresetReference, path: target)
                        : addError(.missingPresetReference, path: target)
                }
            } else if !hasCompleteOverrideTime(assignment) {
                assignment.skipAlarm
                    ? addWarning(.missingPresetReference, path: "\(path).presetID")
                    : addError(.missingPresetReference, path: "\(path).presetID")
            }
        }

        for (index, override) in bundle.overrides.enumerated() {
            // `inherit` should not appear in a canonical bundle (device-local default is not
            // shared). Warn so the user knows the importer will treat it as `silence`.
            if override.alarmBehavior == .inherit {
                addWarning(.holidayBehaviorInherit, path: "overrides[\(index)].alarmBehavior")
            }
            guard let presetID = override.replacementPresetID, !presetIDs.contains(presetID)
            else { continue }
            let path = "overrides[\(index)].replacementPresetID"
            override.skipAlarm
                ? addWarning(.missingPresetReference, path: path)
                : addError(.missingPresetReference, path: path)
        }

        return ShiftBundleValidationResult(errors: errors, warnings: warnings)
    }

    private static func checkLimit(
        _ count: Int,
        max: Int,
        path: String,
        errors: inout [ShiftBundleValidationIssue]
    ) {
        guard count > max else { return }
        errors.append(issue(.tooManyItems, path: path))
    }

    private static func checkDuplicateIDs(
        _ items: [(id: UUID, path: String)],
        errors: inout [ShiftBundleValidationIssue]
    ) {
        var seen: [UUID: String] = [:]
        for item in items {
            if seen[item.id] != nil {
                errors.append(issue(.duplicateID, path: item.path))
            } else {
                seen[item.id] = item.path
            }
        }
    }

    private static func checkDuplicateAssignmentDates(
        _ assignments: [ShiftBundle.AssignmentDTO],
        errors: inout [ShiftBundleValidationIssue]
    ) {
        var seen = Set<CalendarDay>()
        for (index, assignment) in assignments.enumerated() {
            if !seen.insert(assignment.date).inserted {
                errors.append(issue(.duplicateDate, path: "assignments[\(index)].date"))
            }
        }
    }

    private static func checkDuplicateOverrideDates(
        _ overrides: [ShiftBundle.OverrideDTO],
        errors: inout [ShiftBundleValidationIssue]
    ) {
        var seen = Set<CalendarDay>()
        for (index, override) in overrides.enumerated() {
            if !seen.insert(override.date).inserted {
                errors.append(issue(.duplicateDate, path: "overrides[\(index)].date"))
            }
        }
    }

    private static func hasCompleteOverrideTime(_ assignment: ShiftBundle.AssignmentDTO) -> Bool {
        guard
            let hour = assignment.overrideAlarmHour,
            let minute = assignment.overrideAlarmMinute
        else { return false }
        return isValidHour(hour) && isValidMinute(minute)
    }

    private static func issue(
        _ code: ShiftBundleValidationCode,
        path: String
    ) -> ShiftBundleValidationIssue {
        ShiftBundleValidationIssue(code: code, path: path, message: message(code, path: path))
    }

    private static func message(
        _ code: ShiftBundleValidationCode,
        path: String
    ) -> String {
        let format: String
        switch code {
        case .unsupportedVersion:
            format = String(localized: "import.validation.unsupported_version")
        case .futureVersion:
            format = String(localized: "import.validation.future_version")
        case .tooManyItems:
            format = String(localized: "import.validation.too_many_items")
        case .invalidAlarmHour:
            format = String(localized: "import.validation.invalid_alarm_hour")
        case .invalidAlarmMinute:
            format = String(localized: "import.validation.invalid_alarm_minute")
        case .invalidCycleLength:
            format = String(localized: "import.validation.invalid_cycle_length")
        case .slotCountMismatch:
            format = String(localized: "import.validation.slot_count_mismatch")
        case .duplicateID:
            format = String(localized: "import.validation.duplicate_id")
        case .duplicateDate:
            format = String(localized: "import.validation.duplicate_date")
        case .missingPresetReference:
            format = String(localized: "import.validation.missing_preset_reference")
        case .textTooLong:
            format = String(localized: "import.validation.text_too_long")
        case .invalidColorHex:
            format = String(localized: "import.validation.invalid_color_hex")
        case .invalidCrossVacationPolicy:
            format = String(localized: "import.validation.invalid_cross_vacation_policy")
        case .invalidDayStartSlotIndex:
            format = String(localized: "import.validation.invalid_day_start_slot_index")
        case .holidayBehaviorInherit:
            format = String(localized: "import.validation.holiday_behavior_inherit")
        }
        return String(format: format, path)
    }

    private static func isValidHour(_ value: Int) -> Bool {
        (0...23).contains(value)
    }

    private static func isValidMinute(_ value: Int) -> Bool {
        (0...59).contains(value)
    }

    private static func isValidColorHex(_ value: String) -> Bool {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        guard text.count == 6 || text.count == 8 else { return false }
        let hexDigits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return text.unicodeScalars.allSatisfy { hexDigits.contains($0) }
    }
}
