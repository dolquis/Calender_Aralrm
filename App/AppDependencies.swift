import Foundation
import SwiftData
import Observation

/// Top-level container injected via the environment so feature views can reach services.
@Observable
@MainActor
public final class AppDependencies {
    public let modelContainer: ModelContainer
    public let alarmAuthorization: AlarmAuthorization
    public let alarmScheduler: AlarmScheduler
    public let liveActivityController: LiveActivityController
    public var pendingImportBundle: ShiftBundle?

    public init(modelContainer: ModelContainer? = nil) {
        let container = modelContainer ?? SharedPersistence.makeContainer()
        self.modelContainer = container
        let service = AlarmService()
        self.alarmAuthorization = AlarmAuthorization(service: service)
        self.alarmScheduler = AlarmScheduler(
            modelContainer: container,
            service: service
        )
        self.liveActivityController = LiveActivityController(modelContainer: container)
    }

    public func bootstrap() async {
        await alarmAuthorization.refresh()
        await alarmScheduler.refreshScheduledAlarms()
        await liveActivityController.evaluate()
    }
}
