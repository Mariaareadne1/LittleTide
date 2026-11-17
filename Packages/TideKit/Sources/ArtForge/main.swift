import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// ArtForge — renders Little Tide's layered coastal scenes.
//
//   swift run -c release art-forge [scene…] [--preview <dir>]
//
// Writes Sources/TideUI/Scenes/<scene>/{land.jpg, water.jpg, height.png, foam.png,
// widget-small-<0…4>.jpg, widget-medium-<0…4>.jpg}. Deterministic: same input, same pixels.

func writeImage(_ data: [UInt8], width: Int, height: Int, gray: Bool, to url: URL, jpegQuality: Double? = nil) {
    let space = gray ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!
    let bpr = gray ? width : width * 4
    let info: UInt32 = gray ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
    let provider = CGDataProvider(data: Data(data) as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: gray ? 8 : 32, bytesPerRow: bpr,
                        space: space, bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil,
                        shouldInterpolate: true, intent: .defaultIntent)!
    let type = jpegQuality == nil ? UTType.png.identifier : UTType.jpeg.identifier
    let dest = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil)!
    var props: [CFString: Any] = [:]
    if let q = jpegQuality { props[kCGImageDestinationLossyCompressionQuality] = q }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    CGImageDestinationFinalize(dest)
}

func scaled(_ src: [UInt8], sw: Int, sh: Int, crop: (x: Int, y: Int, w: Int, h: Int), to dw: Int, _ dh: Int) -> [UInt8] {
    var out = [UInt8](repeating: 255, count: dw * dh * 4)
    for y in 0..<dh { for x in 0..<dw {
        // Box filter over the source footprint.
        let sx0 = crop.x + x * crop.w / dw, sx1 = max(sx0 + 1, crop.x + (x + 1) * crop.w / dw)
        let sy0 = crop.y + y * crop.h / dh, sy1 = max(sy0 + 1, crop.y + (y + 1) * crop.h / dh)
        var r = 0, g = 0, b = 0, n = 0
        for yy in sy0..<min(sy1, sh) { for xx in sx0..<min(sx1, sw) {
            let i = (yy * sw + xx) * 4; r += Int(src[i]); g += Int(src[i + 1]); b += Int(src[i + 2]); n += 1
        } }
        let o = (y * dw + x) * 4
        out[o] = UInt8(r / max(n, 1)); out[o + 1] = UInt8(g / max(n, 1)); out[o + 2] = UInt8(b / max(n, 1))
    } }
    return out
}

let arguments = CommandLine.arguments.dropFirst()
let previewDir = arguments.firstIndex(of: "--preview").map { URL(fileURLWithPath: arguments[$0 + 1]) }
let wanted = Set(arguments.filter { !$0.hasPrefix("--") && URL(fileURLWithPath: $0) != previewDir })
let scenes = [SceneSpec.eastCoast].filter { wanted.isEmpty || wanted.contains($0.name) }
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("TideUI/Scenes")

for spec in scenes {
    let start = Date()
    let dir = root.appendingPathComponent(spec.name)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let terrain = Terrain(spec: spec)
    let painter = LayerPainter(terrain: terrain)
    let land = painter.land(), water = painter.water(), foam = painter.foam(), wander = painter.wander()
    let w = spec.width, h = spec.height
    print("\(spec.name): layers painted in \(Int(Date().timeIntervalSince(start)))s")

    writeImage(land.pixels, width: w, height: h, gray: false, to: dir.appendingPathComponent("land.jpg"), jpegQuality: 0.86)
    writeImage(water.pixels, width: w, height: h, gray: false, to: dir.appendingPathComponent("water.jpg"), jpegQuality: 0.86)
    // data.png: R = height ((h − heightMin) / heightSpan, dithered), G = foam lace,
    // B = foam wander (0.5 = none). One image because SwiftUI shaders take one image.
    var rng = SplitMix(seed: spec.seed &+ 9)
    var data = [UInt8](repeating: 255, count: w * h * 4)
    for i in 0..<(w * h) {
        let t = clamp01((terrain.heights[i] - Composite.heightMin) / Composite.heightSpan) * 255 + rng.range(-0.5, 0.5)
        data[i * 4] = UInt8(min(max(t.rounded(), 0), 255))
        data[i * 4 + 1] = UInt8(clamp01(foam[i]) * 255)
        data[i * 4 + 2] = UInt8(clamp01(wander[i] * 0.5 + 0.5) * 255)
    }
    writeImage(data, width: w, height: h, gray: false, to: dir.appendingPathComponent("data.png"))
    try? FileManager.default.removeItem(at: dir.appendingPathComponent("height.png"))
    try? FileManager.default.removeItem(at: dir.appendingPathComponent("foam.png"))

    // Composites at five tide levels: widget snapshots (+ optional full-size previews).
    // Widget crops frame the sandy point and its surf.
    let smallCrop = (x: 120, y: 640, w: 900, h: 900)
    let mediumCrop = (x: 0, y: 820, w: 1080, h: 504)
    for step in 0...4 {
        let L = Composite.level(Float(step) / 4)
        var full = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            let c = Composite.pixel(level: L, h: terrain.heights[i], land: land.rgb(x, y), water: water.rgb(x, y), foamLace: foam[i], wander: wander[i], spec: spec)
            full[i * 4] = UInt8(clamp01(c.r) * 255); full[i * 4 + 1] = UInt8(clamp01(c.g) * 255); full[i * 4 + 2] = UInt8(clamp01(c.b) * 255)
        } }
        writeImage(scaled(full, sw: w, sh: h, crop: smallCrop, to: 510, 510), width: 510, height: 510, gray: false,
                   to: dir.appendingPathComponent("widget-small-\(step).jpg"), jpegQuality: 0.84)
        writeImage(scaled(full, sw: w, sh: h, crop: mediumCrop, to: 1092, 510), width: 1092, height: 510, gray: false,
                   to: dir.appendingPathComponent("widget-medium-\(step).jpg"), jpegQuality: 0.84)
        if let previewDir {
            try FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
            writeImage(full, width: w, height: h, gray: false, to: previewDir.appendingPathComponent("\(spec.name)-L\(step).jpg"), jpegQuality: 0.85)
        }
    }
    print("\(spec.name): done in \(Int(Date().timeIntervalSince(start)))s → \(dir.path)")
}
