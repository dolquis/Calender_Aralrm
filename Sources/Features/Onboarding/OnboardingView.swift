import SwiftData
import SwiftUI

public struct OnboardingView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var page = 0
    @State private var isRequestingPermission = false

    public init() {}

    public var body: some View {
        TabView(selection: $page) {
            welcomePage.tag(0)
            permissionPage.tag(1)
            readyPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var isPermissionDenied: Bool {
        dependencies.alarmAuthorization.state == .denied
    }

    @ViewBuilder
    private var welcomePage: some View {
        pageScaffold {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text("onboarding.welcome_title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("onboarding.welcome_subtitle")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        } cta: {
            Button("onboarding.next") {
                withAnimation { page = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var permissionPage: some View {
        pageScaffold {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text("onboarding.permission_title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("onboarding.permission_subtitle")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                bulletRow("onboarding.permission_point_silent", systemImage: "moon.fill")
                bulletRow("onboarding.permission_point_lockscreen", systemImage: "lock.iphone")
                bulletRow("onboarding.permission_point_revocable", systemImage: "gearshape")
            }
        } cta: {
            Button {
                requestPermission()
            } label: {
                if isRequestingPermission {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("onboarding.request_permission").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequestingPermission)

            Button("onboarding.skip") {
                withAnimation { page = 2 }
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var readyPage: some View {
        pageScaffold {
            Image(
                systemName: isPermissionDenied
                    ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
            )
            .font(.system(size: 80))
            .foregroundStyle(isPermissionDenied ? Color.orange : Color.green)
            Text(isPermissionDenied ? "onboarding.denied_title" : "onboarding.ready_title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(isPermissionDenied ? "onboarding.denied_hint" : "onboarding.ready_subtitle")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if isPermissionDenied {
                Button("settings.open_system_settings") {
                    if let url = URL(string: "app-settings:") {
                        openURL(url)
                    }
                }
                .buttonStyle(.bordered)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    bulletRow("onboarding.next_step_1", systemImage: "1.circle.fill")
                    bulletRow("onboarding.next_step_2", systemImage: "2.circle.fill")
                    bulletRow("onboarding.next_step_3", systemImage: "3.circle.fill")
                }
            }
        } cta: {
            Button("onboarding.get_started") {
                seedSamplePresets()
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    /// Shared page chrome: scrollable content so it never clips at large
    /// Dynamic Type sizes, with the call-to-action pinned to the bottom
    /// safe area instead of a fixed offset.
    @ViewBuilder
    private func pageScaffold(
        @ViewBuilder content: () -> some View,
        @ViewBuilder cta: () -> some View
    ) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                cta()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func requestPermission() {
        isRequestingPermission = true
        Task {
            await dependencies.alarmAuthorization.request()
            isRequestingPermission = false
            withAnimation { page = 2 }
        }
    }

    private func bulletRow(_ key: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }

    private func seedSamplePresets() {
        let existing = (try? modelContext.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        guard existing.isEmpty else { return }
        let dayShift = ShiftPreset(
            name: String(localized: "seed.day_shift"),
            colorHex: "#1E88E5",
            defaultAlarmHour: 7,
            defaultAlarmMinute: 0
        )
        let nightShift = ShiftPreset(
            name: String(localized: "seed.night_shift"),
            colorHex: "#E53935",
            defaultAlarmHour: 22,
            defaultAlarmMinute: 0
        )
        modelContext.insert(dayShift)
        modelContext.insert(nightShift)
        try? modelContext.save()
    }

    private func completeOnboarding() {
        let list = (try? modelContext.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let s = list.first else { return }
        s.hasOnboarded = true
        try? modelContext.save()
    }
}
