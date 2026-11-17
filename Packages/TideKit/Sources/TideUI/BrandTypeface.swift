import CoreText
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The editorial serif used for Little Tide's identity, place names and headline tide
/// facts. One switch decides the face; every style in `TypeStyle` goes through it.
///
/// - `newsreader`: Newsreader by Production Type (SIL Open Font License 1.1), bundled as
///   variable fonts with weight and optical-size axes. The licensed stand-in for Canela.
/// - `canela`: Canela by Commercial Type. **Not bundled.** It requires a Commercial Type
///   mobile-app licence. To adopt it, add the licensed files to `Fonts/`, fill in
///   `postScriptNames`, and change `current`. See Documentation/TYPOGRAPHY.md.
public enum BrandTypeface: Sendable {
    case newsreader
    case canela

    public static let current: BrandTypeface = .newsreader

    var fileNames: [String] {
        switch self {
        case .newsreader: return ["Newsreader-Variable.ttf", "Newsreader-Italic-Variable.ttf"]
        case .canela: return []
        }
    }

    /// PostScript names of the roman and italic base faces.
    var postScriptNames: (roman: String, italic: String) {
        switch self {
        case .newsreader: return ("Newsreader16pt-Regular", "Newsreader16pt-Italic")
        case .canela: return ("Canela-Regular", "Canela-RegularItalic")
        }
    }

    /// Whether the face carries variable weight/optical-size axes.
    var isVariable: Bool { self == .newsreader }
}

/// Registers bundled fonts for the current process (app or widget extension).
public enum FontRegistry {
    private static let registration: Bool = {
        let urls = BrandTypeface.current.fileNames.compactMap { name -> URL? in
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            return Bundle.module.url(forResource: base, withExtension: ext, subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: base, withExtension: ext)
        }
        guard !urls.isEmpty else { return false }
        var failed = false
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already registered in this process is fine; anything else is a failure.
                let code = (error?.takeRetainedValue()).map { CFErrorGetCode($0) } ?? 0
                if code != CTFontManagerError.alreadyRegistered.rawValue { failed = true }
            }
        }
        return !failed
    }()

    /// Registers once; returns whether the brand serif is available.
    @discardableResult
    public static func registerBundledFonts() -> Bool {
        _ = registration
        return isBrandSerifAvailable
    }

    public static var isBrandSerifAvailable: Bool {
        CTFontCreateWithName(BrandTypeface.current.postScriptNames.roman as CFString, 12, nil)
            .postScriptNameMatches(BrandTypeface.current.postScriptNames.roman)
    }
}

private extension CTFont {
    func postScriptNameMatches(_ name: String) -> Bool {
        (CTFontCopyPostScriptName(self) as String) == name
    }
}

/// Builds serif fonts with explicit weight and an optical size matched to the rendered size.
enum SerifFactory {
    static let weightAxis = 0x7767_6874 // 'wght'
    static let opticalSizeAxis = 0x6F70_737A // 'opsz'

    static func ctFont(size: CGFloat, weight: Double, italic: Bool) -> CTFont? {
        let face = BrandTypeface.current
        guard FontRegistry.registerBundledFonts() else { return nil }
        let name = italic ? face.postScriptNames.italic : face.postScriptNames.roman
        var attributes: [CFString: Any] = [kCTFontNameAttribute: name]
        if face.isVariable {
            attributes[kCTFontVariationAttribute] = [
                weightAxis: weight,
                opticalSizeAxis: min(max(Double(size), 6), 72),
            ]
        }
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    static func font(size: CGFloat, weight: Double, italic: Bool) -> Font {
        if let ct = ctFont(size: size, weight: weight, italic: italic) { return Font(ct) }
        return fallback(size: size, weight: weight)
    }

    static func fallback(size: CGFloat, weight: Double) -> Font {
        // Never silently claim the brand face: fall back to the system serif.
        .system(size: size, weight: weight >= 500 ? .medium : .regular, design: .serif)
    }

    #if canImport(UIKit)
    /// A serif that participates in Dynamic Type: built at its base size, with the optical
    /// size set for the size it will render at, then scaled by `UIFontMetrics` so it
    /// carries the system's text-style scaling.
    static func dynamicFont(baseSize: CGFloat, scaledSize: CGFloat, weight: Double, italic: Bool,
                            textStyle: UIFont.TextStyle, traits: UITraitCollection) -> Font? {
        let face = BrandTypeface.current
        guard FontRegistry.registerBundledFonts() else { return nil }
        let name = italic ? face.postScriptNames.italic : face.postScriptNames.roman
        var attributes: [UIFontDescriptor.AttributeName: Any] = [.name: name]
        if face.isVariable {
            attributes[UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)] = [
                weightAxis: weight, opticalSizeAxis: min(max(Double(scaledSize), 6), 72),
            ]
        }
        let base = UIFont(descriptor: UIFontDescriptor(fontAttributes: attributes), size: baseSize)
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base, compatibleWith: traits)
        return Font(scaled)
    }
    #endif
}
