import SwiftUI
import TideKit

/// A colour as plain RGB so palettes can be mixed and darkened deterministically.
struct RGB: Sendable {
    let r: Double, g: Double, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    var color: Color { Color(red: r, green: g, blue: b) }
    func color(_ opacity: Double) -> Color { Color(red: r, green: g, blue: b).opacity(opacity) }
}

/// Hand-tuned colours for one painted coast, in a daylight or dusk variant.
struct ArtPalette: Sendable {
    var skyTop: RGB, skyMid: RGB, horizon: RGB, sun: RGB, cloud: RGB
    var farLand: RGB, nearLand: RGB, landShadow: RGB
    var deep: RGB, mid: RGB, shallow: RGB, turquoise: RGB, foam: RGB
    var sand: RGB, sandDeep: RGB, wetSand: RGB
    var rock: RGB, rockLight: RGB, vegetation: RGB, snow: RGB
    var grainLight: Double

    static func make(_ region: CoastRegion, dusk: Bool) -> ArtPalette {
        let day = daylight(region)
        return dusk ? day.dusk() : day
    }

    private static func daylight(_ region: CoastRegion) -> ArtPalette {
        var p = ArtPalette(
            skyTop: RGB(0xA9CBDA), skyMid: RGB(0xD8E5E6), horizon: RGB(0xF3ECDF), sun: RGB(0xF6E2BB), cloud: RGB(0xFFFFFF),
            farLand: RGB(0x8FA19B), nearLand: RGB(0x5D716C), landShadow: RGB(0x3E4F4C),
            deep: RGB(0x1D5E75), mid: RGB(0x2A8695), shallow: RGB(0x5DB7B4), turquoise: RGB(0x86D4C8), foam: RGB(0xFBFAF4),
            sand: RGB(0xE6D6B8), sandDeep: RGB(0xCDB892), wetSand: RGB(0xB49D78),
            rock: RGB(0x3D4847), rockLight: RGB(0x7C8784), vegetation: RGB(0x7E8452), snow: RGB(0xF1F4F4),
            grainLight: 0.05
        )
        switch region {
        case .northernPacific:
            p.skyTop = RGB(0xA3BCC6); p.skyMid = RGB(0xD3DFE0); p.horizon = RGB(0xEDE9E0); p.sun = RGB(0xF1E4C9)
            p.farLand = RGB(0x6B7F7B); p.nearLand = RGB(0x3C504D); p.landShadow = RGB(0x293836)
            p.deep = RGB(0x154D63); p.mid = RGB(0x226F80); p.shallow = RGB(0x4A9EA2); p.turquoise = RGB(0x6EBFB7)
            p.sand = RGB(0xD5C3A2); p.sandDeep = RGB(0xB9A27C); p.wetSand = RGB(0x95805F)
            p.rock = RGB(0x2E3836); p.rockLight = RGB(0x6E7A76); p.vegetation = RGB(0x5D5A2A)
        case .southernCalifornia:
            p.skyTop = RGB(0x9ECAE0); p.skyMid = RGB(0xDDE8E3); p.horizon = RGB(0xF7E2BC); p.sun = RGB(0xF9D696)
            p.farLand = RGB(0xC2AE8C); p.nearLand = RGB(0xA48C69); p.landShadow = RGB(0x7F6A4F)
            p.deep = RGB(0x1A6A8C); p.mid = RGB(0x2795A9); p.shallow = RGB(0x5CC6C0); p.turquoise = RGB(0x8DE0D2)
            p.sand = RGB(0xF0DAB2); p.sandDeep = RGB(0xDEBF8D); p.wetSand = RGB(0xC5A579)
            p.rock = RGB(0x6A5C4D); p.rockLight = RGB(0xA89884)
        case .northAtlantic:
            p.skyTop = RGB(0xB2CBD7); p.skyMid = RGB(0xE0E7E6); p.horizon = RGB(0xF2EEE5)
            p.farLand = RGB(0xA7AD9C); p.nearLand = RGB(0x8E967F)
            p.deep = RGB(0x24596E); p.mid = RGB(0x367F8C); p.shallow = RGB(0x72B6AE); p.turquoise = RGB(0x9CD3C6)
            p.sand = RGB(0xEDE4D0); p.sandDeep = RGB(0xD8CBAE); p.wetSand = RGB(0xC0B194); p.vegetation = RGB(0x8E8C58)
        case .southAtlanticMarsh:
            p.farLand = RGB(0x8C9A72); p.nearLand = RGB(0x6E7C55)
            p.deep = RGB(0x2A6170); p.mid = RGB(0x3E8A8A); p.shallow = RGB(0x78B8A6); p.turquoise = RGB(0x9FD2BE)
            p.sand = RGB(0xE8DCC0); p.vegetation = RGB(0x8A9154)
        case .gulfShore:
            p.horizon = RGB(0xF4EBDA); p.farLand = RGB(0xB9BCAB)
            p.deep = RGB(0x226E7E); p.mid = RGB(0x2F9A9C); p.shallow = RGB(0x66C7B9); p.turquoise = RGB(0x9EE2D2)
            p.sand = RGB(0xF3EBDA); p.sandDeep = RGB(0xE1D4B8); p.wetSand = RGB(0xC9B997); p.rock = RGB(0x6E6253)
        case .tropicalIsland:
            p.skyTop = RGB(0x8EC5E0); p.horizon = RGB(0xF2EADC)
            p.farLand = RGB(0x5C7A66); p.nearLand = RGB(0x3E594B); p.landShadow = RGB(0x2A3F35)
            p.deep = RGB(0x125D88); p.mid = RGB(0x1A8FB3); p.shallow = RGB(0x3DC2C8); p.turquoise = RGB(0x78E2D7)
            p.sand = RGB(0xEEDFC2); p.rock = RGB(0x2B3230); p.rockLight = RGB(0x5D6663)
        case .northernFjord:
            p.skyTop = RGB(0xA8BCC8); p.skyMid = RGB(0xD7E0E3); p.horizon = RGB(0xEAEBE8); p.sun = RGB(0xEDE7D8)
            p.farLand = RGB(0x6E7F8A); p.nearLand = RGB(0x4B5B66)
            p.deep = RGB(0x1E4858); p.mid = RGB(0x2C6773); p.shallow = RGB(0x5A9898); p.turquoise = RGB(0x7FB8B2)
            p.sand = RGB(0xB9B4A8); p.sandDeep = RGB(0x9E998C); p.wetSand = RGB(0x7F7A6F)
        }
        return p
    }

    /// Evening variant for dark appearance: deeper water, dusky sky, warm horizon glow.
    private func dusk() -> ArtPalette {
        let night = RGB(0x0D1820)
        func dim(_ c: RGB, _ t: Double = 0.62) -> RGB { c.mix(night, t) }
        var p = self
        p.skyTop = RGB(0x142230); p.skyMid = RGB(0x2A3A4A); p.horizon = RGB(0x7A6558); p.sun = RGB(0xC98F5E); p.cloud = RGB(0x9AA4B0)
        p.farLand = dim(farLand, 0.55); p.nearLand = dim(nearLand, 0.6); p.landShadow = dim(landShadow, 0.6)
        p.deep = dim(deep, 0.5); p.mid = dim(mid, 0.55); p.shallow = dim(shallow, 0.55); p.turquoise = dim(turquoise, 0.55)
        p.foam = RGB(0xC9D3D2)
        p.sand = dim(sand, 0.6); p.sandDeep = dim(sandDeep, 0.6); p.wetSand = dim(wetSand, 0.6)
        p.rock = dim(rock, 0.5); p.rockLight = dim(rockLight, 0.55); p.vegetation = dim(vegetation, 0.55); p.snow = dim(snow, 0.4)
        p.grainLight = 0.035
        return p
    }
}
