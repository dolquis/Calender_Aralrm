import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    public init(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&rgb)
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        switch trimmed.count {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
            a = 1
        case 8:
            r = Double((rgb >> 24) & 0xFF) / 255
            g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8) & 0xFF) / 255
            a = Double(rgb & 0xFF) / 255
        default:
            r = 0.12
            g = 0.53
            b = 0.95
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    public static let presetPalette: [String] = [
        "#1E88E5", "#43A047", "#FB8C00", "#E53935",
        "#8E24AA", "#00ACC1", "#6D4C41", "#3949AB",
    ]

    // WCAG 2.1 relative luminance (IEC 61966-2-1 sRGB).
    public var relativeLuminance: Double {
        #if canImport(UIKit)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        func lin(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        #else
        return 0
        #endif
    }

    // WCAG 2.1 contrast ratio between two colours (always ≥ 1).
    public func contrastRatio(with other: Color) -> Double {
        let l1 = max(relativeLuminance, other.relativeLuminance)
        let l2 = min(relativeLuminance, other.relativeLuminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    // Returns .white or .black, whichever gives the higher contrast on self as a background.
    public var accessibleForeground: Color {
        relativeLuminance > 0.179 ? .black : .white
    }

    // Returns true when this foreground colour meets WCAG AA (4.5:1) against the given background.
    public func wcagAACompliant(against background: Color) -> Bool {
        contrastRatio(with: background) >= 4.5
    }

    // Human-readable names for the preset palette colours (localisation key form).
    public static let presetPaletteNames: [String: String] = [
        "#1E88E5": "color.blue",
        "#43A047": "color.green",
        "#FB8C00": "color.orange",
        "#E53935": "color.red",
        "#8E24AA": "color.purple",
        "#00ACC1": "color.cyan",
        "#6D4C41": "color.brown",
        "#3949AB": "color.indigo",
    ]
}
