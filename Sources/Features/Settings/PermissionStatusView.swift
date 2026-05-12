import SwiftUI

public struct PermissionStatusView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var isRequesting = false

    public init() {}

    public var body: some View {
        let state = dependencies.alarmAuthorization.state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon(for: state))
                    .foregroundStyle(color(for: state))
                Text(label(for: state))
                Spacer()
            }
            if state != .authorized {
                Button {
                    isRequesting = true
                    Task {
                        let result = await dependencies.alarmAuthorization.request()
                        if result == .authorized {
                            await dependencies.alarmScheduler.refreshScheduledAlarms()
                            await dependencies.liveActivityController.evaluate()
                        }
                        isRequesting = false
                    }
                } label: {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text("settings.request_permission")
                    }
                }
                .disabled(isRequesting)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func icon(for state: AlarmAuthorizationState) -> String {
        switch state {
        case .authorized: "checkmark.seal.fill"
        case .denied: "xmark.seal.fill"
        case .notDetermined: "questionmark.circle.fill"
        }
    }

    private func color(for state: AlarmAuthorizationState) -> Color {
        switch state {
        case .authorized: .green
        case .denied: .red
        case .notDetermined: .orange
        }
    }

    private func label(for state: AlarmAuthorizationState) -> LocalizedStringKey {
        switch state {
        case .authorized: "settings.permission_authorized"
        case .denied: "settings.permission_denied"
        case .notDetermined: "settings.permission_not_determined"
        }
    }
}
