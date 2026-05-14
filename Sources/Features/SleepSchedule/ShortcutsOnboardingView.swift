import SwiftUI

/// Explains iOS API constraints and guides the user to set up a Shortcuts personal automation
/// that uses the app's App Intents to approximate automatic iOS sleep schedule control.
public struct ShortcutsOnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                limitationSection
                step1Section
                step2Section
                step3Section
            }
            .navigationTitle("sleep.shortcuts_guide_title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var limitationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("sleep.limitation_title", systemImage: "lock.shield")
                    .font(.headline)
                Text("sleep.limitation_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("sleep.section_limitation")
        }
    }

    private var step1Section: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("sleep.step1_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("sleep.step1_intents")
                    .font(.subheadline.monospaced())
                    .padding(6)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.vertical, 4)
        } header: {
            Label("sleep.step1_title", systemImage: "1.circle.fill")
        }
    }

    private var step2Section: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("sleep.step2_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("sleep.step2_title", systemImage: "2.circle.fill")
        }
    }

    private var step3Section: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("sleep.step3_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("sleep.step3_title", systemImage: "3.circle.fill")
        }
    }
}
