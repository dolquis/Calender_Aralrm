import Foundation
import SwiftData

// SchemaV6 redefines only the two models that gained columns for P2-ζ (holiday alarm
// control): `HolidayOverride` (+ `alarmBehaviorRaw`) and `AppSettings`
// (+ `holidayAlarmDefaultRaw`). Every other model is unchanged and is shared from
// SchemaV4/SchemaV5 via `SchemaV6.models` (see SchemaV6.swift). Both new columns are
// nullable, so the V5 -> V6 migration stays lightweight; nil values are filled in by
// `HolidayBehaviorBackfill` on first launch.
extension SchemaV6 {
    @Model
    public final class HolidayOverride {
        public enum Kind: Int, Codable, Sendable {
            case publicHoliday
            case paidLeave
            case custom
        }

        @Attribute(.unique) public var id: UUID
        /// Normalized to start-of-day.
        public var date: Date
        public var kindRaw: Int
        public var label: String
        /// Legacy binary flag, kept for `.shiftalarm` backward compatibility and older app
        /// builds. Kept in sync with the effective (`inherit`-resolved) behavior at write
        /// sites and on export. `alarmBehavior` is the source of truth going forward.
        public var skipAlarm: Bool
        public var isVacationGroup: Bool = false
        /// nil = not yet migrated (backfilled from `skipAlarm` by `HolidayBehaviorBackfill`).
        public var alarmBehaviorRaw: Int?
        @Relationship public var replacementPreset: ShiftPreset?

        public init(
            id: UUID = UUID(),
            date: Date,
            kind: Kind,
            label: String,
            skipAlarm: Bool = true,
            isVacationGroup: Bool = false,
            alarmBehaviorRaw: Int? = nil,
            replacementPreset: ShiftPreset? = nil
        ) {
            self.id = id
            self.date = date
            self.kindRaw = kind.rawValue
            self.label = label
            self.skipAlarm = skipAlarm
            self.isVacationGroup = isVacationGroup
            self.alarmBehaviorRaw = alarmBehaviorRaw
            self.replacementPreset = replacementPreset
        }

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .custom }
            set { kindRaw = newValue.rawValue }
        }

        /// Tri-state holiday alarm behavior. Before backfill (`alarmBehaviorRaw == nil`) it
        /// derives from the legacy `skipAlarm` flag so reads are correct even pre-migration:
        /// `skipAlarm == false` means the user explicitly wanted it to ring (`.ring`), while
        /// the default `skipAlarm == true` maps to `.inherit` (follow the app-wide default).
        public var alarmBehavior: HolidayAlarmBehavior {
            get {
                if let raw = alarmBehaviorRaw, let value = HolidayAlarmBehavior(rawValue: raw) {
                    return value
                }
                return skipAlarm ? .inherit : .ring
            }
            set {
                alarmBehaviorRaw = newValue.rawValue
                // Concrete values can keep the legacy flag in sync without the app-wide
                // default. `inherit` requires the default, so leave `skipAlarm` to the
                // write site (see `syncSkipAlarm(globalDefault:)`).
                if newValue != .inherit {
                    skipAlarm = (newValue == .silence)
                }
            }
        }

        /// Resolve `alarmBehavior` against the app-wide default (used by `inherit`).
        public func effectiveBehavior(
            globalDefault: HolidayAlarmBehavior
        ) -> HolidayAlarmBehavior {
            alarmBehavior.resolved(default: globalDefault)
        }

        /// Keep the legacy `skipAlarm` flag consistent with the effective behavior. Call at
        /// write/export sites so `inherit` rows also carry a correct binary flag.
        public func syncSkipAlarm(globalDefault: HolidayAlarmBehavior) {
            skipAlarm = effectiveBehavior(globalDefault: globalDefault) == .silence
        }
    }

    @Model
    public final class AppSettings {
        @Attribute(.unique) public var id: UUID
        public var defaultSoundID: String
        public var lookaheadDays: Int
        public var liveActivityLeadHours: Int
        public var preferredLanguageRaw: String?
        public var hasOnboarded: Bool
        public var patternSuggestionSnoozedUntil: Date?
        public var patternSuggestionSnoozedFingerprint: String?
        public var patternDriftThreshold: Double?
        public var lastAlarmSchedulerRunAt: Date?
        public var lastAlarmSchedulerResultRaw: String?
        /// App-wide holiday alarm default. nil = not set (treated as `.silence`, preserving
        /// the pre-P2-ζ behavior where holidays were silent). Only `ring`/`silence` are
        /// meaningful here; `inherit` is not a valid app-wide default.
        public var holidayAlarmDefaultRaw: Int?

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
            lastAlarmSchedulerResultRaw: String? = nil,
            holidayAlarmDefaultRaw: Int? = nil
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
            self.holidayAlarmDefaultRaw = holidayAlarmDefaultRaw
        }

        /// Stored app-wide default as a tri-state for editing convenience. Reads treat nil as
        /// `.silence`; `inherit` is coerced to `.silence` on read (never a valid app default).
        public var holidayAlarmDefault: HolidayAlarmBehavior {
            get {
                guard let raw = holidayAlarmDefaultRaw,
                    let value = HolidayAlarmBehavior(rawValue: raw)
                else { return .silence }
                return value == .inherit ? .silence : value
            }
            set {
                holidayAlarmDefaultRaw =
                    (newValue == .inherit ? HolidayAlarmBehavior.silence : newValue).rawValue
            }
        }

        /// Concrete app-wide default used by resolution (always `ring` or `silence`).
        public var effectiveHolidayAlarmDefault: HolidayAlarmBehavior {
            holidayAlarmDefault == .ring ? .ring : .silence
        }
    }
}
