import Foundation
import SwiftData

public typealias SwapRecord = SchemaV5.SwapRecord

extension SchemaV5 {
    @Model
    public final class SwapRecord {
        public enum Kind: Int, Codable, Sendable, CaseIterable, Hashable {
            case covered
            case covering
            case exchange
        }

        @Attribute(.unique) public var id: UUID
        /// Normalized to local-timezone start-of-day.
        public var date: Date
        public var kindRaw: Int
        public var counterpartyLabel: String
        public var note: String
        public var createdAt: Date

        public init(
            id: UUID = UUID(),
            date: Date,
            kind: Kind,
            counterpartyLabel: String,
            note: String = "",
            createdAt: Date = .now,
            calendar: Calendar = .current
        ) {
            self.id = id
            self.date = calendar.startOfDay(for: date)
            self.kindRaw = kind.rawValue
            self.counterpartyLabel = counterpartyLabel
            self.note = note
            self.createdAt = createdAt
        }

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .exchange }
            set { kindRaw = newValue.rawValue }
        }
    }
}
