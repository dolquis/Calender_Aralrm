import Foundation
import SwiftData

public typealias VacationPeriod = SchemaV4.VacationPeriod

public enum VacationPeriodError: Error, Equatable, Sendable {
    case tooShort(days: Int)
    case invertedRange
}

public enum CrossVacationPolicy: Int, Codable, Sendable, CaseIterable {
    case invert = 0
    case `continue` = 1
    case resetToDay = 2
}

extension SchemaV4 {
    @Model
    public final class VacationPeriod {
        @Attribute(.unique) public private(set) var id: UUID
        public private(set) var startDate: Date
        public private(set) var endDate: Date
        public var label: String

        fileprivate init(id: UUID, startDate: Date, endDate: Date, label: String) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.label = label
        }

        public static func make(
            id: UUID = UUID(),
            startDate: Date,
            endDate: Date,
            label: String,
            calendar: Calendar = .current
        ) throws -> VacationPeriod {
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: endDate)
            let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? -1
            guard dayCount >= 0 else {
                throw VacationPeriodError.invertedRange
            }
            let inclusiveDays = dayCount + 1
            guard inclusiveDays >= 3 else {
                throw VacationPeriodError.tooShort(days: inclusiveDays)
            }
            return VacationPeriod(id: id, startDate: start, endDate: end, label: label)
        }
    }
}
