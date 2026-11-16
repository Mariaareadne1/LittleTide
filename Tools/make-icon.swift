// Draws the Little Tide app icon (1024×1024) in light, dark and tinted variants.
//   swift Tools/make-icon.swift
// Output: LittleTide/Resources/Assets.xcassets/AppIcon.appiconset/*.png
// The icon is an original mark: a horizon line above one tide-line wave, over a
// sea-glass water field on limestone. Edit the constants below to iterate.
import AppKit

let size = 1024.0
let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("LittleTide/Resources/Assets.xcassets/AppIcon.appiconset")

struct Variant { let name: String; let paper: NSColor?; let water: NSColor; let line: NSColor; let horizon: NSColor }
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let variants = [
    Variant(name: "icon-light", paper: rgb(0xF4F1E9), water: rgb(0x8DA9AB), line: rgb(0xF4F1E9), horizon: rgb(0x24383C)),
    // Dark: transparent background lets iOS supply its dark backdrop.
    Variant(name: "icon-dark", paper: nil, water: rgb(0x5E8286), line: rgb(0xDCE6E4), horizon: rgb(0xEAE5DA)),
    // Tinted: greyscale; iOS applies the user's tint.
    Variant(name: "icon-tinted", paper: nil, water: rgb(0x8A8A8A), line: rgb(0xFFFFFF), horizon: rgb(0xFFFFFF)),
]

for v in variants {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    // Flip to top-left origin.
    ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: 1, y: -1)
    if let paper = v.paper { ctx.setFillColor(paper.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size)) }

    let horizonY = size * 0.46
    // Water field with a gently curved tide-line top.
    let water = CGMutablePath()
    water.move(to: CGPoint(x: 0, y: size * 0.60))
    water.addCurve(to: CGPoint(x: size, y: size * 0.60),
                   control1: CGPoint(x: size * 0.34, y: size * 0.50), control2: CGPoint(x: size * 0.62, y: size * 0.72))
    water.addLine(to: CGPoint(x: size, y: size)); water.addLine(to: CGPoint(x: 0, y: size)); water.closeSubpath()
    ctx.addPath(water); ctx.setFillColor(v.water.cgColor); ctx.fillPath()

    // Tide line: the wave edge, drawn as a fine stroke.
    let tide = CGMutablePath()
    tide.move(to: CGPoint(x: 0, y: size * 0.60))
    tide.addCurve(to: CGPoint(x: size, y: size * 0.60),
                  control1: CGPoint(x: size * 0.34, y: size * 0.50), control2: CGPoint(x: size * 0.62, y: size * 0.72))
    ctx.addPath(tide); ctx.setStrokeColor(v.line.cgColor); ctx.setLineWidth(size * 0.022); ctx.strokePath()

    // Horizon.
    ctx.setStrokeColor(v.horizon.cgColor); ctx.setLineWidth(size * 0.026); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: size * 0.18, y: horizonY)); ctx.addLine(to: CGPoint(x: size * 0.82, y: horizonY)); ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(v.name).png"))
    print("wrote \(v.name).png")
}
