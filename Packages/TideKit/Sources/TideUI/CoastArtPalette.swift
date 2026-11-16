import SwiftUI
import TideKit

/// Hand-tuned colours for each coastal illustration, in a light ("morning") and a dark
/// ("dusk") variant. Muted and natural; no saturated cyan.
struct CoastArtPalette {
    let skyTop: Color
    let skyHorizon: Color
    let sun: Color
    let farLand: Color
    let nearLand: Color
    let seaFar: Color
    let seaNear: Color
    let foam: Color
    let wetSand: Color
    let sand: Color
    let detail: Color

    static func make(_ region: CoastRegion, dark: Bool) -> CoastArtPalette {
        let base = dark ? duskBase : morningBase
        switch region {
        case .pacificHeadlands:
            return base.with(farLand: dark ? hex(0x2C3A3E) : hex(0x9AAAA6), nearLand: dark ? hex(0x1F2A2C) : hex(0x6F7F7A))
        case .northAtlantic:
            return base.with(farLand: dark ? hex(0x34403F) : hex(0xB4B9AE), nearLand: dark ? hex(0x2A3331) : hex(0x8F9686))
        case .southAtlanticMarsh:
            return base.with(farLand: dark ? hex(0x323C33) : hex(0xA9AF93), nearLand: dark ? hex(0x2B3329) : hex(0x8C946F))
        case .gulfShore:
            return base.with(farLand: dark ? hex(0x37403E) : hex(0xBFC2B4), nearLand: dark ? hex(0x3A3630) : hex(0x7D6E5C))
        case .tropicalIsland:
            return base.with(farLand: dark ? hex(0x28332F) : hex(0x7F948A), nearLand: dark ? hex(0x202826) : hex(0x55625B))
        case .northernFjord:
            return base.with(farLand: dark ? hex(0x333D44) : hex(0x98A6AE), nearLand: dark ? hex(0x252E34) : hex(0x6C7A82))
        }
    }

    private static let morningBase = CoastArtPalette(
        skyTop: hex(0xD9E2E1), skyHorizon: hex(0xF3EEE3), sun: hex(0xE9CFA6),
        farLand: .clear, nearLand: .clear,
        seaFar: hex(0x8DA9AB), seaNear: hex(0x6F9196), foam: hex(0xF4F1E9),
        wetSand: hex(0xB9A98F), sand: hex(0xDCCFBA), detail: hex(0x3A4A4C)
    )

    private static let duskBase = CoastArtPalette(
        skyTop: hex(0x1A2427), skyHorizon: hex(0x3C4746), sun: hex(0x9C7A55),
        farLand: .clear, nearLand: .clear,
        seaFar: hex(0x3E5558), seaNear: hex(0x2F4447), foam: hex(0x9FB1B0),
        wetSand: hex(0x4A443A), sand: hex(0x5E574B), detail: hex(0xC9C3B5)
    )

    private func with(farLand: Color, nearLand: Color) -> CoastArtPalette {
        CoastArtPalette(
            skyTop: skyTop, skyHorizon: skyHorizon, sun: sun, farLand: farLand, nearLand: nearLand,
            seaFar: seaFar, seaNear: seaNear, foam: foam, wetSand: wetSand, sand: sand, detail: detail
        )
    }

    static func hex(_ rgb: UInt32) -> Color {
        Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
