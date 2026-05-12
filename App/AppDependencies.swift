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
    public var pendingImport: PendingImportBundle?

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

/// Stable identifier wrapper for an in-flight import payload. Its `id` is generated once per
/// inbound bundle so SwiftUI sheets keyed off it don't churn on unrelated re-renders.
public struct PendingImportBundle: Identifiable, Sendable {
    public let id: UUID
    public let bundle: ShiftBundle

    public init(bundle: ShiftBundle, id: UUID = UUID()) {
        self.id = id
        self.bundle = bundle
    }
}
