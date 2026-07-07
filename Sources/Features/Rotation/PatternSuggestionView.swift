import SwiftData
import SwiftUI

/// Card shown at the top of RotationListView when a repeating shift pattern is detected.
public struct PatternSuggestionView: View {
    let suggestion: ShiftPatternDetector.SuggestedRotation
    let presets: [UUID: ShiftPresetSnapshot]
    let isDriftUpdate: Bool
    let replacingPatternName: String?
    let onAccept: @MainActor () -> Void
    let onReject: @MainActor () -> Void

    public init(
        suggestion: ShiftPatternDetector.SuggestedRotation,
        presets: [UUID: ShiftPresetSnapshot],
        isDriftUpdate: Bool = false,
        replacingPatternName: String? = nil,
        onAccept: @escaping @MainActor () -> Void,
        onReject: @escaping @MainActor () -> Void
    ) {
        self.suggestion = suggestion
        self.presets = presets
        self.isDriftUpdate = isDriftUpdate
        self.replacingPatternName = replacingPatternName
        self.onAccept = onAccept
        self.onReject = onReject
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(
                    systemName: isDriftUpdate
                        ? "arrow.triangle.2.circlepath.circle.fill" : "sparkles"
                )
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
                if isDriftUpdate {
                    Text("pattern.suggestion.drift.title")
                        .font(.headline)
                } else {
                    Text("pattern.suggestion.title")
                        .font(.headline)
                }
            }
            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isDriftUpdate, let replacingPatternName {
                Label {
                    Text(
                        String(
                            format: String(localized: "pattern.suggestion.drift.replace_note"),
                            replacingPatternName
                        )
                    )
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            slotPreview

            HStack(spacing: 12) {
                Button(action: onReject) {
                    Text("pattern.suggestion.reject_30d")
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

    private var bodyText: String {
        if isDriftUpdate {
            return String(
                format: String(localized: "pattern.suggestion.drift.body"),
                suggestion.cycleLength
            )
        }
        return String(format: String(localized: "pattern.suggestion.body"), suggestion.cycleLength)
    }

    @ViewBuilder private var slotPreview: some View {
        let entries = uniquePresetEntries()
        if !entries.isEmpty {
            HStack(spacing: 4) {
                ForEach(entries.enumerated(), id: \.offset) { index, entry in
                    if index > 0 {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                    PresetColorDot(colorHex: entry.colorHex)
                    Text(entry.name)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func uniquePresetEntries() -> [(name: String, colorHex: String?)] {
        var seen = Set<UUID>()
        var entries: [(name: String, colorHex: String?)] = []
        for id in suggestion.slots.compactMap({ $0 }) {
            guard seen.insert(id).inserted else { continue }
            if let snapshot = presets[id] {
                entries.append((snapshot.name, snapshot.colorHex))
            }
        }
        return entries
    }
}
