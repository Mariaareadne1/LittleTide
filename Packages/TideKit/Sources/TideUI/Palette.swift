import SwiftUI

/// "Quiet Coastal Editorial" colour tokens. Each token has a light and a dark value;
/// contrast pairs used for text are checked in `PaletteContrastTests`.
public enum Palette {
    /// Warm limestone paper. Primary background.
    public static let paper = dynamic(light: 0xF4F1E9, dark: 0x121A1C)
    /// Soft fog. Secondary surfaces, information plates.
    public static let fog = dynamic(light: 0xDFE7E5, dark: 0x1C2729)
    /// Sea-glass blue-grey. Tide water, curves, non-text accents.
    public static let seaGlass = dynamic(light: 0x72969B, dark: 0x86AAAE)
    /// Deeper sea-glass for strokes and small text that must pass 4.5:1 on paper.
    public static let seaGlassDeep = dynamic(light: 0x3F6468, dark: 0xA9C6C9)
    /// Deep ink. Primary text.
    public static let ink = dynamic(light: 0x24383C, dark: 0xEAE5DA)
    /// Softer ink for secondary text (≥ 4.5:1 on paper in both modes).
    public static let inkSoft = dynamic(light: 0x405255, dark: 0xBEC3BD)
    /// Driftwood sand. Beach band in the illustration, hairlines.
    public static let sand = dynamic(light: 0xCEBEA8, dark: 0x6E6253)
    /// Teal-black used for glass shadows.
    public static let glassShadow = dynamic(light: 0x0F3B47, dark: 0x000000)
    /// Light veil laid behind text that sits directly on the painted sky.
    public static let skyVeil = dynamic(light: 0xF4F1E9, dark: 0x0F1A22)

    /// Restrained rust/ochre accent: the selected-time marker only.
    public static let rust = dynamic(light: 0xA34F2A, dark: 0xD9875A)

    public static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
import UIKit

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#else
import AppKit

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
