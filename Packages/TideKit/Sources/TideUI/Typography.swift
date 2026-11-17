import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Little Tide's semantic type system. Serif (brand face) for identity and headline tide
/// facts; SF Pro for everything functional. Use `.typeStyle(_:)` rather than `.font(_:)`.
public enum TypeStyle: CaseIterable, Sendable {
    // Serif
    case brand
    case heroLocation
    case heroTideTime
    case sectionHeading
    case eventTitle
    case placeTitleCompact
    case widgetHeroSmall
    case widgetHeroMedium
    case widgetPlace
    // SF Pro
    case body
    case bodyEmphasis
    case data
    case label
    case regionLabel
    case metadata
    case chartLabel
    case widgetSecondary
    case widgetMicro

    struct Spec {
        let size: CGFloat
        let textStyle: Font.TextStyle
        var serifWeight: Double? = nil
        var italic = false
        var sansWeight: Font.Weight = .regular
        var tracking: CGFloat = 0
        var lineSpacing: CGFloat = 0
        var uppercase = false
        var tabular = false
        /// Widgets render at fixed sizes; don't scale with Dynamic Type there.
        var scales = true
    }

    var spec: Spec {
        switch self {
        case .brand: return Spec(size: 27, textStyle: .title2, serifWeight: 420, tracking: -0.3)
        case .heroLocation: return Spec(size: 40, textStyle: .largeTitle, serifWeight: 360, tracking: -0.8, lineSpacing: -2)
        case .heroTideTime: return Spec(size: 33, textStyle: .title, serifWeight: 430, tracking: -0.5, tabular: true)
        case .sectionHeading: return Spec(size: 25, textStyle: .title2, serifWeight: 380, italic: true, tracking: -0.3)
        case .eventTitle: return Spec(size: 20, textStyle: .title3, serifWeight: 420)
        case .placeTitleCompact: return Spec(size: 19, textStyle: .headline, serifWeight: 420)
        case .widgetHeroSmall: return Spec(size: 27, textStyle: .title, serifWeight: 460, tracking: -0.4, tabular: true, scales: false)
        case .widgetHeroMedium: return Spec(size: 28, textStyle: .title, serifWeight: 440, tracking: -0.4, tabular: true, scales: false)
        case .widgetPlace: return Spec(size: 15, textStyle: .subheadline, serifWeight: 440, scales: false)
        case .body: return Spec(size: 15, textStyle: .subheadline, lineSpacing: 2)
        case .bodyEmphasis: return Spec(size: 15, textStyle: .subheadline, sansWeight: .semibold)
        case .data: return Spec(size: 16, textStyle: .callout, sansWeight: .medium, tabular: true)
        case .label: return Spec(size: 13, textStyle: .footnote, sansWeight: .semibold, tracking: 0.2)
        case .regionLabel: return Spec(size: 12, textStyle: .caption, sansWeight: .semibold, tracking: 1.4, uppercase: true)
        case .metadata: return Spec(size: 12, textStyle: .caption, tabular: true)
        case .chartLabel: return Spec(size: 11, textStyle: .caption2, sansWeight: .medium, tabular: true)
        case .widgetSecondary: return Spec(size: 12, textStyle: .caption, sansWeight: .medium, tabular: true, scales: false)
        case .widgetMicro: return Spec(size: 10, textStyle: .caption2, sansWeight: .semibold, tracking: 0.8, uppercase: true, scales: false)
        }
    }

    public var isSerif: Bool { spec.serifWeight != nil }

    /// The point size after Dynamic Type scaling.
    public func scaledSize(for dynamicType: DynamicTypeSize) -> CGFloat {
        let spec = spec
        guard spec.scales else { return spec.size }
        #if canImport(UIKit)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicType))
        return UIFontMetrics(forTextStyle: UIFont.TextStyle(spec.textStyle)).scaledValue(for: spec.size, compatibleWith: traits)
        #else
        return spec.size
        #endif
    }

    public func font(for dynamicType: DynamicTypeSize = .large) -> Font {
        let spec = spec
        let size = scaledSize(for: dynamicType)
        var font: Font
        if let weight = spec.serifWeight {
            font = serifFont(size: size, weight: weight, dynamicType: dynamicType)
        } else if spec.scales {
            // Native text styles: SF Pro with system Dynamic Type behaviour.
            font = .system(spec.textStyle, design: .default, weight: spec.sansWeight)
        } else {
            font = .system(size: size, weight: spec.sansWeight)
        }
        if spec.tabular { font = font.monospacedDigit() }
        return font
    }

    private func serifFont(size: CGFloat, weight: Double, dynamicType: DynamicTypeSize) -> Font {
        let spec = spec
        #if canImport(UIKit)
        if spec.scales {
            let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicType))
            if let font = SerifFactory.dynamicFont(baseSize: spec.size, scaledSize: size, weight: weight, italic: spec.italic,
                                                   textStyle: UIFont.TextStyle(spec.textStyle), traits: traits) {
                return font
            }
        }
        #endif
        return SerifFactory.font(size: size, weight: weight, italic: spec.italic)
    }
}

private struct TypeStyleModifier: ViewModifier {
    let style: TypeStyle
    @Environment(\.dynamicTypeSize) private var dynamicType

    func body(content: Content) -> some View {
        let spec = style.spec
        content
            .font(style.font(for: dynamicType))
            .tracking(spec.tracking)
            .lineSpacing(spec.lineSpacing)
            .textCase(spec.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Applies a semantic Little Tide text style (font, tracking, leading, case).
    public func typeStyle(_ style: TypeStyle) -> some View {
        modifier(TypeStyleModifier(style: style))
    }
}

#if canImport(UIKit)
extension UIContentSizeCategory {
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}

extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        switch style {
        case .largeTitle: self = .largeTitle
        case .title: self = .title1
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .subheadline: self = .subheadline
        case .body: self = .body
        case .callout: self = .callout
        case .footnote: self = .footnote
        case .caption: self = .caption1
        case .caption2: self = .caption2
        @unknown default: self = .body
        }
    }
}
#endif

/// Legacy names kept so existing call sites compile while migrating to `TypeStyle`.
public enum Typography {
    public static var placeTitle: Font { TypeStyle.heroLocation.font() }
    public static var sectionTitle: Font { TypeStyle.sectionHeading.font() }
    public static var eventTime: Font { TypeStyle.heroTideTime.font() }
    public static var dataValue: Font { TypeStyle.data.font() }
    public static var body: Font { TypeStyle.body.font() }
    public static var caption: Font { .system(.footnote) }
    public static var label: Font { TypeStyle.label.font() }
    public static let labelTracking: CGFloat = 1.1
}
