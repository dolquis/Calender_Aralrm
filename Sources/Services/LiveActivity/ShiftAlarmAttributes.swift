import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(ActivityKit)
public struct ShiftAlarmAttributes: ActivityAttributes, Hashable, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var fireDate: Date
        public var presetName: String
        public var colorHex: String

        public init(fireDate: Date, presetName: String, colorHex: String) {
            self.fireDate = fireDate
            self.presetName = presetName
            self.colorHex = colorHex
        }
    }

    public let alarmID: UUID

    public init(alarmID: UUID) {
        self.alarmID = alarmID
    }
}
#else
public struct ShiftAlarmAttributes: Codable, Hashable, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var fireDate: Date
        public var presetName: String
        public var colorHex: String
    }
    public let alarmID: UUID
}
#endif

#if canImport(AlarmKit)
extension ShiftAlarmAttributes: AlarmMetadata {}
#endif
