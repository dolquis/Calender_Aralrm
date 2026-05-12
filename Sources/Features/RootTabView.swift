import SwiftUI

public struct RootTabView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selection: Tab = .calendar

    public init() {}

    public enum Tab: Hashable {
        case calendar, presets, rotation, settings
    }

    public var body: some View {
        @Bindable var deps = dependencies
        TabView(selection: $selection) {
            NavigationStack {
                CalendarMonthView()
            }
            .tabItem {
                Label("tab.calendar", systemImage: "calendar")
            }
            .tag(Tab.calendar)

            NavigationStack {
                PresetListView()
            }
            .tabItem {
                Label("tab.presets", systemImage: "alarm")
            }
            .tag(Tab.presets)

            NavigationStack {
                RotationListView()
            }
            .tabItem {
                Label("tab.rotation", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(Tab.rotation)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("tab.settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .sheet(item: Binding(
            get: { deps.pendingImportBundle.map(PendingImport.init) },
            set: { _ in deps.pendingImportBundle = nil }
        )) { wrapper in
            NavigationStack {
                ImportView(initialBundle: wrapper.bundle)
            }
        }
    }
}

private struct PendingImport: Identifiable {
    let bundle: ShiftBundle
    let id = UUID()
}
