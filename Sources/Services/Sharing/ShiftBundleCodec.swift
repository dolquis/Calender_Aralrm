import Foundation

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
        public var anchorDate: Date
        public var cycleLength: Int
        public var slots: [UUID?]
        public var startDate: Date?
        public var endDate: Date?
        public var priority: Int
        public var isActive: Bool
    }

    public struct AssignmentDTO: Codable, Equatable, Sendable {
        public var date: Date
        public var presetID: UUID?
        public var overrideAlarmHour: Int?
        public var overrideAlarmMinute: Int?
        public var skipAlarm: Bool
        public var note: String
    }

    public struct OverrideDTO: Codable, Equatable, Sendable {
        public var date: Date
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
        encoder.dateEncodingStrategy = .formatted(makeDayFormatter())
        return try encoder.encode(bundle)
    }

    public static func decode(_ data: Data) throws -> ShiftBundle {
        let decoder = JSONDecoder()
        let dayFormatter = makeDayFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = dayFormatter.date(from: str) { return date }
            // Backward-compatibility: accept full ISO-8601 timestamps written by older builds.
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: str) { return date }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(str)")
            )
        }
        return try decoder.decode(ShiftBundle.self, from: data)
    }

    /// "yyyy-MM-dd" formatter in the device's local timezone so date-only strings
    /// round-trip as the same calendar day regardless of where they are decoded.
    private static func makeDayFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }
}
