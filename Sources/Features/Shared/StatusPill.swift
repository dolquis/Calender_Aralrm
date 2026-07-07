import SwiftUI

/// Compact capsule badge that pairs a short text with a semantic tint.
/// Used for rotation "inactive" markers, calendar holiday badges, and
/// the diagnostics status shown in Settings.
public struct StatusPill: View {
    public let textKey: LocalizedStringKey
    public let tint: Color

    public init(_ textKey: LocalizedStringKey, tint: Color = .secondary) {
        self.textKey = textKey
        self.tint = tint
    }

    public var body: some View {
        Text(textKey)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
            .lineLimit(1)
    }
}
