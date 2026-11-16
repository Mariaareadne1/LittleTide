import SwiftUI

/// System fonts only: New York (serif) for place names, SF for data and controls.
public enum Typography {
    public static let placeTitle = Font.system(.largeTitle, design: .serif).weight(.regular)
    public static let placeTitleCompact = Font.system(.title2, design: .serif)
    public static let sectionTitle = Font.system(.title3, design: .serif)
    public static let eventTime = Font.system(.title, design: .default).weight(.medium).monospacedDigit()
    public static let dataValue = Font.system(.body, design: .default).weight(.medium).monospacedDigit()
    public static let body = Font.system(.body)
    public static let caption = Font.system(.footnote)
    /// Small editorial label, e.g. "PREDICTED TIDE · NOAA". Used with `.textCase(.uppercase)`.
    public static let label = Font.system(.caption, design: .default).weight(.semibold)
    public static let labelTracking: CGFloat = 1.1
}
