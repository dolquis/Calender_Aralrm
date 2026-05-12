import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            ShiftPreset.self,
            ShiftAlarm.self,
            DayAssignment.self,
            RotationPattern.self,
            HolidayOverride.self,
            AppSettings.self,
        ]
    }
}
