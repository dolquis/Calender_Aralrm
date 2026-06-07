import Foundation
import SwiftData

public typealias AppSettings = SchemaV2.AppSettings

extension SchemaV2 {
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

        public var effectivePatternDriftThreshold: Double {
            patternDriftThreshold ?? 0.15
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
            patternDriftThreshold: Double = 0.15
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
        }
    }
}
