import Foundation
import SwiftData

public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV2.ShiftPreset.self,
            SchemaV2.ShiftAlarm.self,
            SchemaV2.DayAssignment.self,
            SchemaV2.RotationPattern.self,
            SchemaV2.HolidayOverride.self,
            SchemaV2.AppSettings.self,
        ]
    }
}
