import Foundation
import SwiftData

public enum SharedPersistence {
    public static var appGroupID: String { AppRuntimeConfiguration.appGroupID }
    public static let storeFileName = "ShiftAlarm.store"

    public static func storeURL() -> URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID)
        {
            return groupURL.appendingPathComponent(storeFileName)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(storeFileName)
    }

    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                "ShiftAlarmStore",
                schema: schema,
                url: storeURL()
            )
        }
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ShiftAlarmMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            assertionFailure("Failed to create ModelContainer: \(error)")
            return try! ModelContainer(
                for: schema,
                migrationPlan: ShiftAlarmMigrationPlan.self,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        }
    }
}
