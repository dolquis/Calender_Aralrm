import Foundation
import SwiftData

public enum SchemaV6: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            // Unchanged models are shared from their last-defined version.
            SchemaV4.ShiftPreset.self,
            SchemaV4.ShiftAlarm.self,
            SchemaV4.DayAssignment.self,
            SchemaV4.RotationPattern.self,
            SchemaV4.VacationPeriod.self,
            SchemaV5.SwapRecord.self,
            // Redefined for P2-ζ (added a nullable column each).
            SchemaV6.HolidayOverride.self,
            SchemaV6.AppSettings.self,
        ]
    }
}
