import SwiftUI
import SwiftData

public struct OnboardingView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
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
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
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
                .padding(.horizontal)
            Spacer()
            Button("onboarding.next") {
                withAnimation { page = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 60)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var permissionPage: some View {
        VStack(spacing: 24) {
            Spacer()
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
                .padding(.horizontal)
            Spacer()
            Button {
                isRequestingPermission = true
                Task {
                    await dependencies.alarmAuthorization.request()
                    isRequestingPermission = false
                    withAnimation { page = 2 }
                }
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
            .padding(.bottom, 60)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("onboarding.ready_title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("onboarding.ready_subtitle")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button("onboarding.get_started") {
                seedSamplePresets()
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 60)
        }
        .padding(.horizontal)
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
