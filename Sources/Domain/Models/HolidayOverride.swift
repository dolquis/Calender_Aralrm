import Foundation
import SwiftData

// The live model is SchemaV6 (P2-ζ added `alarmBehaviorRaw`). The SchemaV4 definition
// below is frozen — it is the shape referenced by the V4 and V5 versioned schemas and
// must not change, or the migration history breaks. New columns live in SchemaV6
// (see SchemaV6Models.swift).
public typealias HolidayOverride = SchemaV6.HolidayOverride

extension SchemaV4 {
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
        public var skipAlarm: Bool
        public var isVacationGroup: Bool = false
        @Relationship public var replacementPreset: ShiftPreset?

        public init(
            id: UUID = UUID(),
            date: Date,
            kind: Kind,
            label: String,
            skipAlarm: Bool = true,
            isVacationGroup: Bool = false,
            replacementPreset: ShiftPreset? = nil
        ) {
            self.id = id
            self.date = date
            self.kindRaw = kind.rawValue
            self.label = label
            self.skipAlarm = skipAlarm
            self.isVacationGroup = isVacationGroup
            self.replacementPreset = replacementPreset
        }

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .custom }
            set { kindRaw = newValue.rawValue }
        }
    }
}
