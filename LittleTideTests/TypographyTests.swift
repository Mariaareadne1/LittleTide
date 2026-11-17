import CoreText
import SwiftUI
import XCTest
import TideUI

/// The brand serif must really load (never a silent fallback to the system face).
final class TypographyTests: XCTestCase {
    func testNewsreaderRegistersAndResolves() {
        XCTAssertTrue(FontRegistry.registerBundledFonts(), "brand serif failed to register")
        let font = CTFontCreateWithName("Newsreader16pt-Regular" as CFString, 40, nil)
        XCTAssertEqual(CTFontCopyFamilyName(font) as String, "Newsreader")
    }

    func testVariableAxesApplyWeightAndOpticalSize() throws {
        FontRegistry.registerBundledFonts()
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: "Newsreader16pt-Regular",
            kCTFontVariationAttribute: [0x7767_6874: 360.0, 0x6F70_737A: 40.0],
        ] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, 40, nil)
        let variation = try XCTUnwrap(CTFontCopyVariation(font) as? [Int: Double])
        XCTAssertEqual(variation[0x7767_6874] ?? 0, 360, accuracy: 0.5)
        XCTAssertEqual(variation[0x6F70_737A] ?? 0, 40, accuracy: 0.5)
    }

    func testSerifStylesScaleWithDynamicType() {
        let base = TypeStyle.heroLocation.scaledSize(for: .large)
        let large = TypeStyle.heroLocation.scaledSize(for: .accessibility3)
        XCTAssertEqual(base, 40, accuracy: 0.01)
        XCTAssertGreaterThan(large, base)
        // Widgets are fixed-size by design.
        XCTAssertEqual(TypeStyle.widgetHeroSmall.scaledSize(for: .accessibility3), TypeStyle.widgetHeroSmall.scaledSize(for: .large))
    }

    func testSerifOnlyForDisplayStyles() {
        let serif: Set<String> = ["brand", "heroLocation", "heroTideTime", "sectionHeading", "eventTitle", "placeTitleCompact",
                                  "widgetHeroSmall", "widgetHeroMedium", "widgetPlace"]
        for style in TypeStyle.allCases {
            XCTAssertEqual(style.isSerif, serif.contains("\(style)"), "\(style)")
        }
    }
}
