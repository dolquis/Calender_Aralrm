import Foundation
import SwiftData

public typealias ShiftAlarm = SchemaV4.ShiftAlarm

extension SchemaV4 {
    @Model
    public final class ShiftAlarm {
        public static let emptyPendingCancelData = Data("[]".utf8)

        @Attribute(.unique) public var id: UUID
        /// Absolute fire date in the user's calendar.
        public var fireDate: Date
        public var label: String
        public var soundID: String
        public var isEnabled: Bool
        /// AlarmKit registration identifier. nil when not yet scheduled.
        @Attribute(originalName: "alarmKitID") public var currentAlarmKitID: UUID?
        /// AlarmKit IDs that must be canceled before this row can be considered fully reconciled.
        public var pendingCancelData: Data = emptyPendingCancelData
        /// True for bedtime reminder alarms; false (default) for wake alarms.
        public var isBedtimeReminder: Bool = false
        @Relationship public var assignment: DayAssignment?

        public init(
            id: UUID = UUID(),
            fireDate: Date,
            label: String,
            soundID: String = AlarmSound.systemDefault.id,
            isEnabled: Bool = true,
            alarmKitID: UUID? = nil,
            currentAlarmKitID: UUID? = nil,
            pendingCancelIDs: [UUID] = [],
            isBedtimeReminder: Bool = false,
            assignment: DayAssignment? = nil
        ) {
            self.id = id
            self.fireDate = fireDate
            self.label = label
            self.soundID = soundID
            self.isEnabled = isEnabled
            self.currentAlarmKitID = currentAlarmKitID ?? alarmKitID
            self.pendingCancelData = Self.encodePendingCancelIDs(pendingCancelIDs)
            self.isBedtimeReminder = isBedtimeReminder
            self.assignment = assignment
        }

        public var alarmKitID: UUID? {
            get { currentAlarmKitID }
            set { currentAlarmKitID = newValue }
        }

        public var pendingCancelIDs: [UUID] {
            get {
                (try? JSONDecoder().decode([UUID].self, from: pendingCancelData)) ?? []
            }
            set {
                pendingCancelData = Self.encodePendingCancelIDs(newValue)
            }
        }

        public func appendPendingCancelID(_ id: UUID) {
            var ids = pendingCancelIDs
            guard !ids.contains(id) else { return }
            ids.append(id)
            pendingCancelIDs = ids
        }

        public func removePendingCancelID(_ id: UUID) {
            pendingCancelIDs = pendingCancelIDs.filter { $0 != id }
        }

        private static func encodePendingCancelIDs(_ ids: [UUID]) -> Data {
            (try? JSONEncoder().encode(ids)) ?? emptyPendingCancelData
        }
    }
}
