import Foundation

/// Calendar-day value (year/month/day) used for fields that represent "the same day" regardless of
/// the device time zone. Encoded as a "YYYY-MM-DD" string so bundles round-trip across time zones.
public struct CalendarDay: Codable, Equatable, Sendable, Hashable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = components.year, let m = components.month, let d = components.day else {
            return nil
        }
        self.year = y
        self.month = m
        self.day = d
    }

    public func date(in calendar: Calendar = .current) -> Date? {
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        return calendar.date(from: dc).map { calendar.startOfDay(for: $0) }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected YYYY-MM-DD calendar day, got \(raw)"
            )
        }
        self.year = y
        self.month = m
        self.day = d
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%04d-%02d-%02d", year, month, day))
    }
}

public struct ShiftBundle: Codable, Equatable, Sendable {
    public var version: Int
    public var exportedAt: Date
    public var presets: [PresetDTO]
    public var patterns: [RotationDTO]
    public var assignments: [AssignmentDTO]
    public var overrides: [OverrideDTO]

    public init(
        version: Int = 1,
        exportedAt: Date = .now,
        presets: [PresetDTO] = [],
        patterns: [RotationDTO] = [],
        assignments: [AssignmentDTO] = [],
        overrides: [OverrideDTO] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.presets = presets
        self.patterns = patterns
        self.assignments = assignments
        self.overrides = overrides
    }

    public struct PresetDTO: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var colorHex: String
        public var defaultAlarmHour: Int?
        public var defaultAlarmMinute: Int?
        public var soundID: String
        public var note: String
    }

    public struct RotationDTO: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var anchorDate: CalendarDay
        public var cycleLength: Int
        public var slots: [UUID?]
        public var startDate: CalendarDay?
        public var endDate: CalendarDay?
        public var priority: Int
        public var isActive: Bool
    }

    public struct AssignmentDTO: Codable, Equatable, Sendable {
        public var date: CalendarDay
        public var presetID: UUID?
        public var overrideAlarmHour: Int?
        public var overrideAlarmMinute: Int?
        public var skipAlarm: Bool
        public var note: String
    }

    public struct OverrideDTO: Codable, Equatable, Sendable {
        public var date: CalendarDay
        public var kind: HolidayOverride.Kind
        public var label: String
        public var skipAlarm: Bool
        public var replacementPresetID: UUID?
    }
}

public enum ShiftBundleCodec {
    public static func encode(_ bundle: ShiftBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    public static func decode(_ data: Data) throws -> ShiftBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShiftBundle.self, from: data)
    }
}
