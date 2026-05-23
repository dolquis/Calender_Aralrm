import BackgroundTasks
import Foundation

public enum BGRefreshController {
    public static var identifier: String { AppRuntimeConfiguration.bgRefreshTaskIdentifier }
    /// Earliest delay before the system re-runs the refresh task, in seconds.
    /// Exposed so tests can assert the request matches the documented schedule.
    public static let earliestRefreshInterval: TimeInterval = 60 * 60 * 8

    public static func registerLaunchHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    /// `submit` is injectable so unit tests can verify the request without touching the system
    /// scheduler (which raises in non-app contexts).
    public static func scheduleNext(
        submit: (BGTaskRequest) throws -> Void = { try BGTaskScheduler.shared.submit($0) }
    ) {
        do {
            try submit(makeRequest())
        } catch {
            // BG submission failures are not fatal — system will reschedule next foreground cycle.
        }
    }

    /// Builds the refresh request. Exposed internally so tests can assert its shape.
    static func makeRequest() -> BGAppRefreshTaskRequest {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestRefreshInterval)
        return request
    }

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext()
        let completion = TaskCompletion(task: task)
        let work = Task {
            let deps = await MainActor.run { AppDependencies() }
            await deps.bootstrap()
            return true
        }
        task.expirationHandler = {
            work.cancel()
        }
        Task {
            _ = await work.value
            completion.setCompleted(success: true)
        }
    }

    private final class TaskCompletion: @unchecked Sendable {
        private let task: BGAppRefreshTask

        init(task: BGAppRefreshTask) {
            self.task = task
        }

        func setCompleted(success: Bool) {
            task.setTaskCompleted(success: success)
        }
    }
}
