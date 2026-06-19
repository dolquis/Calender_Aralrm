import Foundation
import SwiftData

public typealias RotationPattern = SchemaV3.RotationPattern

extension SchemaV3 {
    @Model
    public final class RotationPattern {
        @Attribute(.unique) public var id: UUID
        public var name: String
        public var anchorDate: Date
        public var cycleLength: Int
        /// Length must equal cycleLength. Element is preset.id or nil (= rest day).
        /// Stored as JSON Data because SwiftData supports primitive arrays unevenly across versions.
        public var slotsData: Data
        public var startDate: Date?
        public var endDate: Date?
        public var priority: Int
        public var isActive: Bool

        public init(
            id: UUID = UUID(),
            name: String,
            anchorDate: Date,
            cycleLength: Int,
            slots: [UUID?],
            startDate: Date? = nil,
            endDate: Date? = nil,
            priority: Int = 0,
            isActive: Bool = true
        ) {
            self.id = id
            self.name = name
            self.anchorDate = anchorDate
            self.cycleLength = cycleLength
            self.slotsData =
                (try? JSONEncoder().encode(slots.map { $0?.uuidString })) ?? Data("[]".utf8)
            self.startDate = startDate
            self.endDate = endDate
            self.priority = priority
            self.isActive = isActive
        }

        public var slots: [UUID?] {
            get {
                guard let strings = try? JSONDecoder().decode([String?].self, from: slotsData)
                else {
                    return []
                }
                return strings.map { $0.flatMap(UUID.init(uuidString:)) }
            }
            set {
                slotsData =
                    (try? JSONEncoder().encode(newValue.map { $0?.uuidString }))
                    ?? Data("[]".utf8)
            }
        }
    }
}
