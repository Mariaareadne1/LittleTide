import Foundation

/// The app icon: a square crop of the painted East Coast point at mid tide, with no figures.
/// Light is the painting; dark is the same painting deepened for dark Home Screens; tinted is
/// its luminance so iOS can apply the user's tint.
func renderIcon(spec: SceneSpec, to directory: URL) throws {
    let terrain = Terrain(spec: spec)
    let painter = LayerPainter(terrain: terrain)
    let land = painter.land(includeFigures: false), water = painter.water(includeCraft: false)
    let foam = painter.foam(), wander = painter.wander()
    let w = spec.width, h = spec.height
    let level = Composite.level(0.5)
    var full = [UInt8](repeating: 255, count: w * h * 4)
    for y in 0..<h { for x in 0..<w {
        let i = y * w + x
        let c = Composite.pixel(level: level, h: terrain.heights[i], land: land.rgb(x, y), water: water.rgb(x, y),
                                foamLace: foam[i], wander: wander[i], spec: spec)
        full[i * 4] = UInt8(clamp01(c.r) * 255); full[i * 4 + 1] = UInt8(clamp01(c.g) * 255); full[i * 4 + 2] = UInt8(clamp01(c.b) * 255)
    } }
    // The sandy point, its surf and open water, centred on the curve of the beach.
    let crop = (x: iconCrop[0], y: iconCrop[1], w: iconCrop[2], h: iconCrop[2])
    let light = scaled(full, sw: w, sh: h, crop: crop, to: 1024, 1024)
    writeImage(light, width: 1024, height: 1024, gray: false, to: directory.appendingPathComponent("icon-light.png"))

    var dark = light, tinted = light
    for p in stride(from: 0, to: light.count, by: 4) {
        let r = Float(light[p]) / 255, g = Float(light[p + 1]) / 255, b = Float(light[p + 2]) / 255
        let luma = clamp01(0.2126 * r + 0.7152 * g + 0.0722 * b)
        // Dark: deepen sand and water but keep the foam bright (exposure falls less for
        // light pixels), with a slight pull toward deep teal.
        let foamness = clamp01((luma - 0.78) / 0.15)
        let exposure = 0.58 + 0.34 * foamness
        dark[p] = UInt8(clamp01(r * exposure + 0.01) * 255)
        dark[p + 1] = UInt8(clamp01(g * exposure + 0.03) * 255)
        dark[p + 2] = UInt8(clamp01(b * exposure + 0.05) * 255)
        let v = UInt8(luma * 255)
        tinted[p] = v; tinted[p + 1] = v; tinted[p + 2] = v
    }
    writeImage(dark, width: 1024, height: 1024, gray: false, to: directory.appendingPathComponent("icon-dark.png"))
    writeImage(tinted, width: 1024, height: 1024, gray: false, to: directory.appendingPathComponent("icon-tinted.png"))
}

/// Square crop (x, y, side) in the 1080×2340 scene. `ICON_CROP="x,y,side"` overrides it
/// while iterating.
let iconCrop: [Int] = (ProcessInfo.processInfo.environment["ICON_CROP"] ?? "300,900,780")
    .split(separator: ",").compactMap { Int($0) }
