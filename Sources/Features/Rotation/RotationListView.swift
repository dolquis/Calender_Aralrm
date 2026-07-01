import SwiftData
import SwiftUI

public struct RotationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: [SortDescriptor(\RotationPattern.priority, order: .reverse)]) private var patterns:
        [RotationPattern]
    @Query private var settingsList: [AppSettings]
    @State private var editing: RotationPattern?
    @State private var creating = false
    @State private var suggestion: PatternSuggestionResolver.Result?
    @State private var presetSnapshots: [UUID: ShiftPresetSnapshot] = [:]

    public init() {}

    private var settings: AppSettings? { settingsList.first }

    public var body: some View {
        List {
            if let suggestion, isSuggestionVisible(suggestion.suggestion) {
                Section {
                    PatternSuggestionView(
                        suggestion: suggestion.suggestion,
                        presets: presetSnapshots,
                        isDriftUpdate: suggestion.isDriftUpdate,
                        onAccept: { acceptSuggestion(suggestion) },
                        onReject: { rejectSuggestion(suggestion) }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if patterns.isEmpty {
                ContentUnavailableView(
                    "rotation.empty_title",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("rotation.empty_subtitle")
                )
            } else {
                ForEach(patterns) { pattern in
                    Button {
                        editing = pattern
                    } label: {
                        row(for: pattern)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("tab.rotation")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $creating) { RotationEditorView(pattern: nil) }
        .sheet(item: $editing) { p in RotationEditorView(pattern: p) }
        .task { await detectPattern() }
    }

    // MARK: - Pattern detection

    @MainActor
    private func detectPattern() async {
        let input = DayResolverInputBuilder.make(
            context: modelContext,
            calendar: Calendar.current
        )
        presetSnapshots = input.presets
        let resolver = PatternSuggestionResolver(
            driftThreshold: settings?.effectivePatternDriftThreshold ?? 0.15
        )
        suggestion = resolver.resolve(
            input: input,
            today: Date.now,
            calendar: Calendar.current,
            snoozedFingerprint: settings?.patternSuggestionSnoozedFingerprint,
            snoozedUntil: settings?.patternSuggestionSnoozedUntil
        )
    }

    private func isSuggestionVisible(
        _ s: ShiftPatternDetector.SuggestedRotation,
        now: Date = Date.now
    ) -> Bool {
        PatternSuggestionResolver.isVisible(
            s,
            snoozedFingerprint: settings?.patternSuggestionSnoozedFingerprint,
            snoozedUntil: settings?.patternSuggestionSnoozedUntil,
            now: now
        )
    }

    private func acceptSuggestion(_ context: PatternSuggestionResolver.Result) {
        let s = context.suggestion
        let replacingPattern = context.replacingPatternID
            .flatMap { replacingID in patterns.first(where: { $0.id == replacingID }) }
        let replacementDateBounds =
            replacingPattern
            .map { (startDate: $0.startDate, endDate: $0.endDate) }
        if let replacingPattern {
            replacingPattern.isActive = false
        }
        let nextPriority = replacingPattern?.priority ?? (patterns.map(\.priority).max() ?? -1) + 1
        let patternName =
            context.isDriftUpdate
            ? String(localized: "pattern.suggestion.drift.default_name")
            : String(localized: "pattern.suggestion.default_name")
        let pattern = RotationPattern(
            name: patternName,
            anchorDate: s.anchorDate,
            cycleLength: s.cycleLength,
            slots: s.slots,
            startDate: replacementDateBounds?.startDate,
            endDate: replacementDateBounds?.endDate,
            priority: nextPriority,
            isActive: true
        )
        modelContext.insert(pattern)
        // Snooze the suggestion (365 days) so it doesn't reappear after accept.
        if let settings {
            settings.patternSuggestionSnoozedUntil = Calendar.current.date(
                byAdding: .day, value: 365, to: Date.now)
            settings.patternSuggestionSnoozedFingerprint = s.fingerprint
        }
        try? modelContext.save()
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
        suggestion = nil
    }

    private func rejectSuggestion(_ context: PatternSuggestionResolver.Result) {
        guard let settings else { return }
        let s = context.suggestion
        settings.patternSuggestionSnoozedUntil = Calendar.current.date(
            byAdding: .day, value: 30, to: Date.now)
        settings.patternSuggestionSnoozedFingerprint = s.fingerprint
        try? modelContext.save()
        suggestion = nil
    }

    // MARK: - Row

    private func row(for pattern: RotationPattern) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pattern.name).font(.headline)
                if !pattern.isActive {
                    Text("rotation.inactive")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                        .accessibilityHidden(true)
                }
                Spacer()
            }
            Text(String(localized: "rotation.cycle_label") + ": \(pattern.cycleLength)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: pattern))
    }

    private func rowAccessibilityLabel(for pattern: RotationPattern) -> String {
        var label = pattern.name
        label += ", " + String(localized: "rotation.cycle_label") + ": \(pattern.cycleLength)"
        if !pattern.isActive {
            label += ", " + String(localized: "rotation.inactive")
        }
        return label
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(patterns[i])
        }
        try? modelContext.save()
        Task { await dependencies.alarmScheduler.refreshScheduledAlarms() }
    }
}
