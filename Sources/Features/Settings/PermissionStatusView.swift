import SwiftUI

public struct PermissionStatusView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL
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
            if state == .denied {
                Button("settings.open_system_settings") {
                    if let url = URL(string: "app-settings:") {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else if state == .notDetermined {
                Button {
                    isRequesting = true
                    Task {
                        await dependencies.alarmAuthorization.request()
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
