import Foundation

public struct PatternSuggestionResolver: Sendable {
    public struct Result: Equatable, Sendable {
        public let suggestion: ShiftPatternDetector.SuggestedRotation
        public let replacingPatternID: UUID?

        public init(
            suggestion: ShiftPatternDetector.SuggestedRotation,
            replacingPatternID: UUID?
        ) {
            self.suggestion = suggestion
            self.replacingPatternID = replacingPatternID
        }

        public var isDriftUpdate: Bool { replacingPatternID != nil }
    }

    public let detector: ShiftPatternDetector
    public let driftThreshold: Double

    public init(
        detector: ShiftPatternDetector = ShiftPatternDetector(),
        driftThreshold: Double = AppSettings.defaultPatternDriftThreshold
    ) {
        self.detector = detector
        self.driftThreshold = driftThreshold
    }

    public func resolve(
        input: DayResolverInput,
        today: Date,
        calendar: Calendar,
        snoozedFingerprint: String? = nil,
        snoozedUntil: Date? = nil
    ) -> Result? {
        let activePatterns = input.rotations
            .filter(\.isActive)
            .sorted { $0.priority > $1.priority }
        let driftPatterns = detector.patternsDrivingRecentWindow(
            activePatterns: activePatterns,
            presets: input.presets,
            today: today,
            calendar: calendar
        )

        for pattern in driftPatterns {
            let patternManualAssignments = detector.manualAssignmentsDrivenByPattern(
                pattern,
                activePatterns: activePatterns,
                manualAssignments: input.manualAssignments,
                presets: input.presets,
                calendar: calendar
            )
            guard
                let drift = detector.detectDrift(
                    pattern: pattern,
                    recentManualAssignments: patternManualAssignments,
                    presets: input.presets,
                    today: today,
                    calendar: calendar,
                    threshold: driftThreshold
                ),
                !activePatterns.contains(where: {
                    detector.matchesPatternIdentity($0, suggestion: drift, calendar: calendar)
                }),
                Self.isVisible(
                    drift,
                    snoozedFingerprint: snoozedFingerprint,
                    snoozedUntil: snoozedUntil,
                    now: today
                )
            else { continue }

            return Result(suggestion: drift, replacingPatternID: pattern.id)
        }

        guard
            let detected = detector.detect(
                manualAssignments: input.manualAssignments,
                presets: input.presets,
                today: today,
                calendar: calendar
            ),
            !activePatterns.contains(where: {
                detector.matchesPatternIdentity($0, suggestion: detected, calendar: calendar)
            }),
            Self.isVisible(
                detected,
                snoozedFingerprint: snoozedFingerprint,
                snoozedUntil: snoozedUntil,
                now: today
            )
        else { return nil }

        return Result(suggestion: detected, replacingPatternID: nil)
    }

    public static func isVisible(
        _ suggestion: ShiftPatternDetector.SuggestedRotation,
        snoozedFingerprint: String?,
        snoozedUntil: Date?,
        now: Date
    ) -> Bool {
        guard
            let snoozedUntil,
            let snoozedFingerprint,
            snoozedFingerprint == suggestion.fingerprint,
            now < snoozedUntil
        else {
            return true
        }
        return false
    }
}
