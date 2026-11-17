import CoreGraphics
import Foundation

/// Small human details, painted in the reference's oblique-overhead style. People are
/// placed only on sand that stays dry at the highest tide, and craft only in water deep
/// enough that the tide never reaches them, so no detail implies a wrong tide.
enum Figure {
    /// Someone sitting on a towel, knees up, seen from above-behind.
    case sitter(v: Float, towel: UInt32, shirt: UInt32, hair: UInt32, facing: Float)
    /// Someone walking toward the water, with footprints behind.
    case walker(v: Float, shirt: UInt32, hair: UInt32)
    /// A beach umbrella with a towel in its shade.
    case umbrella(v: Float, canopy: UInt32, stripe: UInt32)
}

enum Craft {
    /// Wooden rowboat at anchor, oars shipped.
    case rowboat(u: Float, v: Float, angle: Float)
    /// Sea kayak with a paddler.
    case kayak(u: Float, v: Float, angle: Float, hull: UInt32)
    /// A swimmer, arms out.
    case swimmer(u: Float, v: Float, angle: Float, cap: UInt32)
    /// Someone on a paddleboard.
    case paddleboard(u: Float, v: Float, angle: Float, board: UInt32)
}

extension CGContext {
    func fillEllipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ color: RGB, _ alpha: CGFloat = 1, angle: CGFloat = 0) {
        saveGState()
        translateBy(x: c.x, y: c.y); rotate(by: angle)
        setFillColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: alpha)
        fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        restoreGState()
    }

    func fillRoundedRect(_ c: CGPoint, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: RGB, _ alpha: CGFloat = 1, angle: CGFloat = 0) {
        saveGState()
        translateBy(x: c.x, y: c.y); rotate(by: angle)
        setFillColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: alpha)
        addPath(CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
        fillPath()
        restoreGState()
    }

    func limb(_ a: CGPoint, _ b: CGPoint, _ width: CGFloat, _ color: RGB) {
        setStrokeColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: 1)
        setLineWidth(width); setLineCap(.round)
        beginPath(); move(to: a); addLine(to: b); strokePath()
    }
}

extension LayerPainter {
    static let skin: [RGB] = [RGB(0xE8B99A), RGB(0xC98E6A), RGB(0x8E5A3C), RGB(0xF0C8A8)]

    /// Finds, on row v, the x where the beach reaches `height` coming from the sea side.
    func dryBeachX(v: Float, height target: Float) -> Int? {
        let y = Int(v * Float(spec.height - 1))
        var best: Int?
        for x in stride(from: spec.width - 1, through: 0, by: -1) {
            let h = terrain.heights[y * spec.width + x]
            if h >= target, terrain.rockMask[y * spec.width + x] < 0.05 { best = x; break }
        }
        return best
    }

    func paintFigures(_ ctx: CGContext, scale: CGFloat) {
        let sand = spec.sand.at(0.5)
        for (index, figure) in spec.figures.enumerated() {
            let skin = Self.skin[index % Self.skin.count]
            switch figure {
            case let .sitter(v, towel, shirt, hair, facing):
                // High-tide line is ~0.545; keep a generous dry margin.
                guard let x = dryBeachX(v: v, height: 0.585) else { continue }
                let c = CGPoint(x: CGFloat(x) - 34 * scale, y: CGFloat(v * Float(spec.height)))
                let a = CGFloat(facing)
                ctx.fillRoundedRect(CGPoint(x: c.x + 10 * scale, y: c.y + 8 * scale), 54 * scale, 30 * scale, 4 * scale, sand.scaled(0.7), 0.35, angle: a)
                ctx.fillRoundedRect(c, 52 * scale, 28 * scale, 3 * scale, RGB(towel), 1, angle: a)
                ctx.fillRoundedRect(CGPoint(x: c.x, y: c.y - 6 * scale), 52 * scale, 5 * scale, 1, RGB(0xFFFFFF), 0.7, angle: a)
                // shadow of the body
                ctx.fillEllipse(CGPoint(x: c.x + 16 * scale, y: c.y + 12 * scale), 16 * scale, 9 * scale, sand.scaled(0.55), 0.45, angle: a)
                // legs (knees up toward the sea), torso, arms, head
                let hip = CGPoint(x: c.x - 4 * scale, y: c.y + 2 * scale)
                let knee = CGPoint(x: hip.x + 16 * scale, y: hip.y - 8 * scale)
                let foot = CGPoint(x: knee.x + 8 * scale, y: knee.y + 10 * scale)
                ctx.limb(hip, knee, 6 * scale, skin); ctx.limb(knee, foot, 5 * scale, skin)
                ctx.limb(CGPoint(x: hip.x, y: hip.y + 4 * scale), CGPoint(x: knee.x, y: knee.y + 5 * scale), 6 * scale, skin.scaled(0.92))
                ctx.fillEllipse(CGPoint(x: hip.x - 4 * scale, y: hip.y - 6 * scale), 8 * scale, 11 * scale, RGB(shirt), 1, angle: -0.3)
                ctx.limb(CGPoint(x: hip.x - 2 * scale, y: hip.y - 12 * scale), CGPoint(x: knee.x - 2 * scale, y: knee.y - 2 * scale), 4 * scale, skin)
                ctx.fillEllipse(CGPoint(x: hip.x - 8 * scale, y: hip.y - 18 * scale), 6 * scale, 6 * scale, skin)
                ctx.fillEllipse(CGPoint(x: hip.x - 10 * scale, y: hip.y - 20 * scale), 6 * scale, 5 * scale, RGB(hair), 0.95)
            case let .walker(v, shirt, hair):
                guard let x = dryBeachX(v: v, height: 0.58) else { continue }
                let c = CGPoint(x: CGFloat(x) - 22 * scale, y: CGFloat(v * Float(spec.height)))
                // footprints trailing inland
                for k in 1...9 {
                    let fx = c.x - CGFloat(k) * 11 * scale, fy = c.y - CGFloat(k) * 6 * scale + (k % 2 == 0 ? 3 : -3) * scale
                    ctx.fillEllipse(CGPoint(x: fx, y: fy), 2.4 * scale, 1.5 * scale, sand.scaled(0.72), 0.7, angle: 0.5)
                }
                ctx.fillEllipse(CGPoint(x: c.x + 12 * scale, y: c.y + 6 * scale), 15 * scale, 5 * scale, sand.scaled(0.55), 0.4, angle: 0.4)
                ctx.limb(CGPoint(x: c.x, y: c.y + 2 * scale), CGPoint(x: c.x + 5 * scale, y: c.y + 12 * scale), 4.5 * scale, skin)
                ctx.limb(CGPoint(x: c.x, y: c.y + 2 * scale), CGPoint(x: c.x - 4 * scale, y: c.y + 12 * scale), 4.5 * scale, skin.scaled(0.9))
                ctx.fillEllipse(CGPoint(x: c.x, y: c.y - 4 * scale), 7 * scale, 9 * scale, RGB(shirt))
                ctx.fillEllipse(CGPoint(x: c.x, y: c.y - 15 * scale), 5.5 * scale, 5.5 * scale, skin)
                ctx.fillEllipse(CGPoint(x: c.x - 1 * scale, y: c.y - 17 * scale), 5.5 * scale, 4 * scale, RGB(hair))
            case let .umbrella(v, canopy, stripe):
                guard let x = dryBeachX(v: v, height: 0.6) else { continue }
                let c = CGPoint(x: CGFloat(x) - 50 * scale, y: CGFloat(v * Float(spec.height)))
                ctx.fillEllipse(CGPoint(x: c.x + 22 * scale, y: c.y + 18 * scale), 38 * scale, 30 * scale, sand.scaled(0.55), 0.4)
                ctx.fillRoundedRect(CGPoint(x: c.x + 18 * scale, y: c.y + 30 * scale), 26 * scale, 46 * scale, 3 * scale, RGB(0xF4EFE4), 1, angle: 0.3)
                for k in 0..<8 {
                    let a0 = CGFloat(k) * .pi / 4, a1 = a0 + .pi / 4
                    ctx.setFillColor(red: CGFloat(RGB(k % 2 == 0 ? canopy : stripe).r), green: CGFloat(RGB(k % 2 == 0 ? canopy : stripe).g),
                                     blue: CGFloat(RGB(k % 2 == 0 ? canopy : stripe).b), alpha: 1)
                    ctx.beginPath(); ctx.move(to: c)
                    ctx.addArc(center: c, radius: 34 * scale, startAngle: a0, endAngle: a1, clockwise: false)
                    ctx.closePath(); ctx.fillPath()
                }
                ctx.fillEllipse(c, 3 * scale, 3 * scale, RGB(0xFFFFFF))
            }
        }
    }

    func paintCraft(_ ctx: CGContext, scale: CGFloat) {
        let water = spec.water
        for craft in spec.craft {
            switch craft {
            case let .rowboat(u, v, angle):
                let c = CGPoint(x: CGFloat(u) * CGFloat(spec.width), y: CGFloat(v) * CGFloat(spec.height))
                let a = CGFloat(angle)
                ctx.fillEllipse(CGPoint(x: c.x + 14 * scale, y: c.y + 16 * scale), 78 * scale, 26 * scale, water.at(0.95).scaled(0.55), 0.55, angle: a)
                // gentle ripples around the hull
                ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: a)
                for k in 1...3 {
                    ctx.setStrokeColor(red: 0.85, green: 0.97, blue: 0.96, alpha: 0.28 / CGFloat(k))
                    ctx.setLineWidth(2 * scale)
                    ctx.strokeEllipse(in: CGRect(x: -(78 + CGFloat(k) * 14) * scale, y: -(24 + CGFloat(k) * 9) * scale,
                                                 width: (156 + CGFloat(k) * 28) * scale, height: (48 + CGFloat(k) * 18) * scale))
                }
                // hull: painted outer, wooden inside, planks and thwarts
                let hull = CGMutablePath()
                hull.move(to: CGPoint(x: -76 * scale, y: 0))
                hull.addQuadCurve(to: CGPoint(x: 70 * scale, y: 0), control: CGPoint(x: 0, y: -48 * scale))
                hull.addQuadCurve(to: CGPoint(x: -76 * scale, y: 0), control: CGPoint(x: 0, y: 48 * scale))
                ctx.addPath(hull); ctx.setFillColor(red: 0.95, green: 0.93, blue: 0.86, alpha: 1); ctx.fillPath()
                let inner = CGMutablePath()
                inner.move(to: CGPoint(x: -66 * scale, y: 0))
                inner.addQuadCurve(to: CGPoint(x: 60 * scale, y: 0), control: CGPoint(x: 0, y: -38 * scale))
                inner.addQuadCurve(to: CGPoint(x: -66 * scale, y: 0), control: CGPoint(x: 0, y: 38 * scale))
                ctx.addPath(inner); ctx.setFillColor(red: 0.63, green: 0.45, blue: 0.29, alpha: 1); ctx.fillPath()
                ctx.addPath(inner); ctx.clip()
                for k in -3...3 {
                    ctx.setStrokeColor(red: 0.5, green: 0.34, blue: 0.21, alpha: 0.6); ctx.setLineWidth(1.2 * scale)
                    ctx.beginPath(); ctx.move(to: CGPoint(x: -70 * scale, y: CGFloat(k) * 6 * scale)); ctx.addLine(to: CGPoint(x: 70 * scale, y: CGFloat(k) * 6 * scale)); ctx.strokePath()
                }
                ctx.resetClip()
                for x in [-28, 4, 34] as [CGFloat] {
                    ctx.fillRoundedRect(CGPoint(x: x * scale, y: 0), 9 * scale, 44 * scale, 2 * scale, RGB(0xC79B6A))
                }
                // oars shipped along the gunwales
                for side in [-1, 1] as [CGFloat] {
                    ctx.limb(CGPoint(x: -36 * scale, y: side * 22 * scale), CGPoint(x: 52 * scale, y: side * 30 * scale), 3 * scale, RGB(0xD9B88A))
                    ctx.fillEllipse(CGPoint(x: 60 * scale, y: side * 31 * scale), 12 * scale, 4.5 * scale, RGB(0xD9B88A), 1, angle: side * 0.08)
                }
                ctx.restoreGState()
            case let .kayak(u, v, angle, hullColor):
                let c = CGPoint(x: CGFloat(u) * CGFloat(spec.width), y: CGFloat(v) * CGFloat(spec.height))
                let a = CGFloat(angle)
                ctx.fillEllipse(CGPoint(x: c.x + 10 * scale, y: c.y + 10 * scale), 70 * scale, 11 * scale, water.at(0.95).scaled(0.55), 0.5, angle: a)
                ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: a)
                ctx.setStrokeColor(red: 0.85, green: 0.97, blue: 0.96, alpha: 0.35); ctx.setLineWidth(2 * scale)
                ctx.beginPath(); ctx.move(to: CGPoint(x: -70 * scale, y: -8 * scale)); ctx.addLine(to: CGPoint(x: -150 * scale, y: -26 * scale)); ctx.strokePath()
                ctx.beginPath(); ctx.move(to: CGPoint(x: -70 * scale, y: 8 * scale)); ctx.addLine(to: CGPoint(x: -150 * scale, y: 26 * scale)); ctx.strokePath()
                ctx.fillEllipse(.zero, 68 * scale, 10 * scale, RGB(hullColor))
                ctx.fillEllipse(CGPoint(x: -4 * scale, y: 0), 12 * scale, 6 * scale, RGB(0x2B2B2B))
                ctx.limb(CGPoint(x: -4 * scale, y: -34 * scale), CGPoint(x: 6 * scale, y: 34 * scale), 2.6 * scale, RGB(0xE8E2D2))
                ctx.fillEllipse(CGPoint(x: -4 * scale, y: -36 * scale), 4 * scale, 8 * scale, RGB(0x1F2A30))
                ctx.fillEllipse(CGPoint(x: 6 * scale, y: 36 * scale), 4 * scale, 8 * scale, RGB(0x1F2A30))
                ctx.fillEllipse(CGPoint(x: -4 * scale, y: 0), 6 * scale, 6 * scale, RGB(0xE84B2C))
                ctx.fillEllipse(CGPoint(x: -4 * scale, y: 0), 4 * scale, 4 * scale, Self.skin[1])
                ctx.restoreGState()
            case let .swimmer(u, v, angle, cap):
                let c = CGPoint(x: CGFloat(u) * CGFloat(spec.width), y: CGFloat(v) * CGFloat(spec.height))
                let a = CGFloat(angle)
                ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: a)
                ctx.setStrokeColor(red: 0.9, green: 0.98, blue: 0.97, alpha: 0.45); ctx.setLineWidth(2 * scale)
                ctx.strokeEllipse(in: CGRect(x: -26 * scale, y: -14 * scale, width: 52 * scale, height: 28 * scale))
                let skin = Self.skin[0].scaled(0.9)
                ctx.limb(CGPoint(x: 0, y: 0), CGPoint(x: 20 * scale, y: -14 * scale), 4 * scale, skin)
                ctx.limb(CGPoint(x: 0, y: 0), CGPoint(x: 20 * scale, y: 14 * scale), 4 * scale, skin)
                ctx.fillEllipse(CGPoint(x: -10 * scale, y: 0), 12 * scale, 6 * scale, RGB(0x2F4A6B), 0.8)
                ctx.limb(CGPoint(x: -18 * scale, y: -3 * scale), CGPoint(x: -34 * scale, y: -6 * scale), 4 * scale, skin.scaled(0.8))
                ctx.limb(CGPoint(x: -18 * scale, y: 3 * scale), CGPoint(x: -34 * scale, y: 7 * scale), 4 * scale, skin.scaled(0.8))
                ctx.fillEllipse(CGPoint(x: 6 * scale, y: 0), 6 * scale, 6 * scale, RGB(cap))
                ctx.restoreGState()
            case let .paddleboard(u, v, angle, board):
                let c = CGPoint(x: CGFloat(u) * CGFloat(spec.width), y: CGFloat(v) * CGFloat(spec.height))
                let a = CGFloat(angle)
                ctx.fillEllipse(CGPoint(x: c.x + 8 * scale, y: c.y + 8 * scale), 52 * scale, 13 * scale, water.at(0.95).scaled(0.55), 0.45, angle: a)
                ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: a)
                ctx.fillEllipse(.zero, 50 * scale, 12 * scale, RGB(board))
                ctx.limb(CGPoint(x: -4 * scale, y: -3 * scale), CGPoint(x: -4 * scale, y: 3 * scale), 6 * scale, Self.skin[2])
                ctx.fillEllipse(CGPoint(x: 0, y: 0), 6 * scale, 8 * scale, RGB(0xF2EEE6))
                ctx.fillEllipse(CGPoint(x: 2 * scale, y: 0), 4.5 * scale, 4.5 * scale, Self.skin[2])
                ctx.limb(CGPoint(x: -6 * scale, y: -16 * scale), CGPoint(x: 10 * scale, y: 20 * scale), 2 * scale, RGB(0x333333))
                ctx.restoreGState()
            }
        }
    }
}
