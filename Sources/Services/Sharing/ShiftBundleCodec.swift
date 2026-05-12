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
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    public static func decode(_ data: Data) throws -> ShiftBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShiftBundle.self, from: data)
    }
}
