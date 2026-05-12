import Foundation
import BackgroundTasks

public enum BGRefreshController {
    public static let identifier = "com.example.shiftalarm.refreshAlarms"

    public static func registerLaunchHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    public static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 8)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // BG submission failures are not fatal — system will reschedule next foreground cycle.
        }
    }

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext()
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
            task.setTaskCompleted(success: true)
        }
    }
}
