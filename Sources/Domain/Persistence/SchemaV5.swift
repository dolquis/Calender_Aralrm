import Foundation
import SwiftData

public enum SchemaV5: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV4.ShiftPreset.self,
            SchemaV4.ShiftAlarm.self,
            SchemaV4.DayAssignment.self,
            SchemaV4.RotationPattern.self,
            SchemaV4.HolidayOverride.self,
            SchemaV4.AppSettings.self,
            SchemaV4.VacationPeriod.self,
            SchemaV5.SwapRecord.self,
        ]
    }
}
