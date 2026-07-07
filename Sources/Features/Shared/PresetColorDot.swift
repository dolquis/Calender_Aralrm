import SwiftUI

/// Small circular swatch representing a shift preset color.
/// Used by the calendar day cells and rotation slot previews so the
/// size and shape of the color coding stays consistent across screens.
public struct PresetColorDot: View {
    public enum EmptyStyle {
        /// Renders an invisible placeholder that keeps the layout height.
        case placeholder
        /// Renders an outlined circle (e.g. a rest day in a rotation).
        case outline
    }

    public let colorHex: String?
    public let emptyStyle: EmptyStyle

    @ScaledMetric(relativeTo: .callout) private var dotSize: CGFloat = 8

    public init(colorHex: String?, emptyStyle: EmptyStyle = .placeholder) {
        self.colorHex = colorHex
        self.emptyStyle = emptyStyle
    }

    public var body: some View {
        Group {
            if let colorHex {
                Circle()
                    .fill(Color(hex: colorHex))
            } else {
                switch emptyStyle {
                case .placeholder:
                    Circle()
                        .fill(Color.clear)
                case .outline:
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .frame(width: dotSize, height: dotSize)
        .accessibilityHidden(true)
    }
}
