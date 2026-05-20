import SwiftUI
import SwiftData

/// Card shown at the top of RotationListView when a repeating shift pattern is detected.
public struct PatternSuggestionView: View {
    let suggestion: ShiftPatternDetector.SuggestedRotation
    let presets: [UUID: ShiftPresetSnapshot]
    let onAccept: @MainActor () -> Void
    let onReject: @MainActor () -> Void

    public init(
        suggestion: ShiftPatternDetector.SuggestedRotation,
        presets: [UUID: ShiftPresetSnapshot],
        onAccept: @escaping @MainActor () -> Void,
        onReject: @escaping @MainActor () -> Void
    ) {
        self.suggestion = suggestion
        self.presets = presets
        self.onAccept = onAccept
        self.onReject = onReject
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("pattern.suggestion.title")
                    .font(.headline)
            }
            Text(String(format: String(localized: "pattern.suggestion.body"), suggestion.cycleLength))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            slotPreview

            HStack(spacing: 12) {
                Button(action: onReject) {
                    Text("pattern.suggestion.reject")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(String(localized: "pattern.suggestion.reject.a11y"))

                Button(action: onAccept) {
                    Text("pattern.suggestion.accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "pattern.suggestion.accept.a11y"))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var slotPreview: some View {
        let names = uniquePresetNames()
        if !names.isEmpty {
            Text(names.joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func uniquePresetNames() -> [String] {
        var seen = Set<UUID>()
        var names: [String] = []
        for id in suggestion.slots.compactMap({ $0 }) {
            guard seen.insert(id).inserted else { continue }
            if let name = presets[id]?.name { names.append(name) }
        }
        return names
    }
}
