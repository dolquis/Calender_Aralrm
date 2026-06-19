import Foundation
import SwiftData

public enum SchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV3.ShiftPreset.self,
            SchemaV3.ShiftAlarm.self,
            SchemaV3.DayAssignment.self,
            SchemaV3.RotationPattern.self,
            SchemaV3.HolidayOverride.self,
            SchemaV3.AppSettings.self,
        ]
    }
}
