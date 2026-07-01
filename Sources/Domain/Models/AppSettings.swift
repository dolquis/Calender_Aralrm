import Foundation
import SwiftData

public typealias AppSettings = SchemaV4.AppSettings

extension SchemaV4 {
    @Model
    public final class AppSettings {
        @Attribute(.unique) public var id: UUID
        public var defaultSoundID: String
        public var lookaheadDays: Int
        public var liveActivityLeadHours: Int
        public var preferredLanguageRaw: String?
        public var hasOnboarded: Bool
        /// Snooze expiry for pattern suggestion card. nil = not snoozed.
        public var patternSuggestionSnoozedUntil: Date?
        /// Fingerprint of the snoozed suggestion. New fingerprint bypasses snooze.
        public var patternSuggestionSnoozedFingerprint: String?
        /// Manual override mismatch ratio that triggers accepted-pattern drift suggestions.
        public var patternDriftThreshold: Double?
        /// Last time `AlarmScheduler` completed a refresh attempt.
        public var lastAlarmSchedulerRunAt: Date?
        /// Human-readable scheduler result. Structured diagnostics are deferred to P3-8.
        public var lastAlarmSchedulerResultRaw: String?

        public static let defaultPatternDriftThreshold = 0.15

        public var effectivePatternDriftThreshold: Double {
            patternDriftThreshold ?? Self.defaultPatternDriftThreshold
        }

        public init(
            id: UUID = UUID(),
            defaultSoundID: String = AlarmSound.systemDefault.id,
            lookaheadDays: Int = 30,
            liveActivityLeadHours: Int = 8,
            preferredLanguageRaw: String? = nil,
            hasOnboarded: Bool = false,
            patternSuggestionSnoozedUntil: Date? = nil,
            patternSuggestionSnoozedFingerprint: String? = nil,
            patternDriftThreshold: Double = AppSettings.defaultPatternDriftThreshold,
            lastAlarmSchedulerRunAt: Date? = nil,
            lastAlarmSchedulerResultRaw: String? = nil
        ) {
            self.id = id
            self.defaultSoundID = defaultSoundID
            self.lookaheadDays = lookaheadDays
            self.liveActivityLeadHours = liveActivityLeadHours
            self.preferredLanguageRaw = preferredLanguageRaw
            self.hasOnboarded = hasOnboarded
            self.patternSuggestionSnoozedUntil = patternSuggestionSnoozedUntil
            self.patternSuggestionSnoozedFingerprint = patternSuggestionSnoozedFingerprint
            self.patternDriftThreshold = patternDriftThreshold
            self.lastAlarmSchedulerRunAt = lastAlarmSchedulerRunAt
            self.lastAlarmSchedulerResultRaw = lastAlarmSchedulerResultRaw
        }
    }
}
