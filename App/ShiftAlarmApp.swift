import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct ShiftAlarmApp: App {
    @State private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BGRefreshController.registerLaunchHandler()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(dependencies)
                .modelContainer(dependencies.modelContainer)
                .task {
                    await dependencies.bootstrap()
                }
                .onOpenURL { url in
                    DeepLinkRouter.handle(url, dependencies: dependencies)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                BGRefreshController.scheduleNext()
            case .active:
                Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
            default:
                break
            }
        }
    }
}
