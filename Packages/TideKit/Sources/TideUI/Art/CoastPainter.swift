import SwiftUI
import TideKit

/// Paints the static (tide-independent) layers: sky, land, open water and its textures.
struct CoastBackdropPainter {
    let scene: CoastScene
    let palette: ArtPalette

    func paint(_ context: inout GraphicsContext) {
        let h = scene.horizon
        let s = scene.scale
        // Sky.
        context.fill(Path(scene.rect(0, 0, 1, h + 0.01)), with: .linearGradient(
            Gradient(stops: [.init(color: palette.skyTop.color, location: 0), .init(color: palette.skyMid.color, location: 0.55),
                             .init(color: palette.horizon.color, location: 1)]),
            startPoint: scene.point(0.5, 0), endPoint: scene.point(0.5, h)))
        // Sun and glow.
        let sunCenter = scene.point(0.7, h - 0.13)
        let glowRadius = scene.size.width * (scene.region == .southernCalifornia ? 0.55 : 0.4)
        context.fill(Path(ellipseIn: CGRect(x: sunCenter.x - glowRadius, y: sunCenter.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                     with: .radialGradient(Gradient(colors: [palette.sun.color(0.55), palette.sun.color(0)]), center: sunCenter, startRadius: 0, endRadius: glowRadius))
        let sunRadius = scene.size.width * 0.045
        context.fill(Path(ellipseIn: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)),
                     with: .color(palette.sun.mix(RGB(0xFFFFFF), 0.4).color(0.9)))
        paintClouds(&context)
        paintGulls(&context)

        // Land, with atmospheric perspective.
        context.fill(scene.farLand, with: .linearGradient(Gradient(colors: [palette.farLand.color, palette.farLand.mix(palette.horizon, 0.35).color]),
                                                          startPoint: scene.point(0.5, h - 0.25), endPoint: scene.point(0.5, h)))
        context.fill(scene.snowCaps, with: .color(palette.snow.color(0.92)))

        // Open water: deep at the horizon, brighter toward the shore.
        context.fill(Path(scene.rect(0, h, 1, 1 - h)), with: .linearGradient(
            Gradient(stops: [.init(color: palette.deep.mix(palette.horizon, 0.18).color, location: 0), .init(color: palette.deep.color, location: 0.12),
                             .init(color: palette.mid.color, location: 0.55), .init(color: palette.shallow.color, location: 1)]),
            startPoint: scene.point(0.5, h), endPoint: scene.point(0.5, 1)))
        paintSwells(&context, scale: s)
        paintGlitter(&context, center: sunCenter.x / scene.size.width, scale: s)
        if scene.region == .northernPacific { paintKelp(&context, scale: s) }
        if let head = scene.nearHeadland {
            context.fill(head, with: .linearGradient(Gradient(colors: [palette.nearLand.color, palette.landShadow.color]),
                                                     startPoint: scene.point(0.85, h), endPoint: scene.point(1, h + 0.2)))
        }
    }

    private func paintClouds(_ context: inout GraphicsContext) {
        var rng = SeededRandom(seed: scene.stableSeed)
        var layer = context
        layer.addFilter(.blur(radius: 9 * scene.scale))
        for _ in 0..<4 {
            let x = rng.range(-0.1, 0.8), y = rng.range(0.06, Double(scene.horizon) * 0.6)
            let w = rng.range(0.25, 0.5), hgt = rng.range(0.025, 0.05)
            layer.fill(Path(ellipseIn: scene.rect(x, y, w, hgt)), with: .color(palette.cloud.color(rng.range(0.25, 0.5))))
        }
    }

    private func paintGulls(_ context: inout GraphicsContext) {
        guard [.northernPacific, .southernCalifornia, .northAtlantic, .gulfShore].contains(scene.region) else { return }
        let ink = palette.foam.color(0.8)
        // Over the water, where no title is ever set.
        for (x, dy, w) in [(0.2, 0.05, 0.02), (0.25, 0.075, 0.015)] as [(CGFloat, CGFloat, CGFloat)] {
            let yy = scene.horizon + dy * (1 - scene.horizon)
            var gull = Path()
            gull.move(to: scene.point(x - w, yy))
            gull.addQuadCurve(to: scene.point(x, yy + 0.004), control: scene.point(x - w * 0.5, yy - w * 0.6))
            gull.addQuadCurve(to: scene.point(x + w, yy), control: scene.point(x + w * 0.5, yy - w * 0.6))
            context.stroke(gull, with: .color(ink), style: StrokeStyle(lineWidth: 1.1 * scene.scale, lineCap: .round))
        }
    }

    /// Painterly swell strokes, longer and wider toward the viewer.
    private func paintSwells(_ context: inout GraphicsContext, scale: CGFloat) {
        var rng = SeededRandom(seed: scene.stableSeed &+ 11)
        let h = scene.horizon
        for i in 0..<34 {
            let t = CGFloat(i) / 34
            let y = h + 0.006 + pow(t, 1.7) * (1 - h) * 0.9
            let x = CGFloat(rng.range(-0.1, 0.9))
            let length = CGFloat(rng.range(0.08, 0.3)) * (0.5 + t)
            var path = Path()
            path.move(to: scene.point(x, y))
            path.addQuadCurve(to: scene.point(x + length, y + 0.002), control: scene.point(x + length / 2, y - 0.006 * (0.4 + t)))
            let isCrest = i % 3 != 0
            let color = isCrest ? palette.foam.color(0.18 + 0.2 * Double(t)) : palette.deep.color(0.35)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: (0.6 + 2.2 * t) * scale, lineCap: .round))
        }
    }

    private func paintGlitter(_ context: inout GraphicsContext, center: CGFloat, scale: CGFloat) {
        var rng = SeededRandom(seed: scene.stableSeed &+ 23)
        let h = scene.horizon
        for _ in 0..<46 {
            let t = CGFloat(pow(rng.next(), 1.6))
            let y = h + 0.004 + t * (1 - h) * 0.45
            let spread = 0.05 + 0.18 * t
            let x = center + CGFloat(rng.range(-1, 1)) * spread
            let w = (0.004 + 0.018 * t) * CGFloat(rng.range(0.5, 1.2))
            let dash = Path(roundedRect: scene.rect(x, y, w, 0.0025 + 0.002 * t), cornerRadius: 1)
            context.fill(dash, with: .color(palette.sun.mix(RGB(0xFFFFFF), 0.7).color(rng.range(0.35, 0.8))))
        }
    }

    private func paintKelp(_ context: inout GraphicsContext, scale: CGFloat) {
        var rng = SeededRandom(seed: scene.stableSeed &+ 31)
        let h = scene.horizon
        for _ in 0..<6 {
            let x = CGFloat(rng.range(0.05, 0.55)), y = h + CGFloat(rng.range(0.06, 0.2)) * (1 - h)
            var strand = Path()
            strand.move(to: scene.point(x, y))
            strand.addCurve(to: scene.point(x + 0.07, y + 0.008), control1: scene.point(x + 0.02, y - 0.012), control2: scene.point(x + 0.05, y + 0.015))
            context.stroke(strand, with: .color(palette.vegetation.color(0.55)), style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round))
            for k in 0..<3 {
                let px = x + 0.02 * CGFloat(k + 1)
                context.fill(Path(ellipseIn: scene.rect(px, y - 0.002, 0.008, 0.0045)), with: .color(palette.vegetation.color(0.65)))
            }
        }
    }
}

/// Paints the tide-dependent layers: beach, shallow water, rocks and foam.
struct CoastShorePainter {
    let scene: CoastScene
    let palette: ArtPalette

    func paint(_ context: inout GraphicsContext) {
        let s = scene.scale
        let h = scene.horizon
        let waterAbove = scene.edgePath(closedToTop: true)

        // Light through shallow water: turquoise band and a hint of sand under the surface.
        var shallow = context
        shallow.clip(to: waterAbove)
        let bandTop = scene.waterline - 0.16 * (1 - h)
        shallow.fill(Path(scene.rect(0, bandTop, 1, 1 - bandTop)), with: .linearGradient(
            Gradient(stops: [.init(color: palette.turquoise.color(0), location: 0), .init(color: palette.turquoise.color(0.45), location: 0.6),
                             .init(color: palette.turquoise.mix(palette.sand, 0.45).color(0.8), location: 0.95)]),
            startPoint: scene.point(0.5, bandTop), endPoint: scene.point(0.5, scene.waterline + 0.04 * (1 - h))))
        paintCaustics(&shallow, scale: s)

        // Rocks / pilings; the submerged part is veiled by water.
        for (rock, box) in scene.shallowsRocks {
            context.fill(rock, with: .linearGradient(Gradient(colors: [palette.rockLight.color, palette.rock.color]),
                                                     startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY)))
        }
        for (rock, _) in scene.shallowsRocks { shallow.fill(rock, with: .color(palette.mid.mix(palette.turquoise, 0.3).color(0.8))) }

        // Sand below the water's edge, with grain.
        var sand = context
        sand.clip(to: scene.belowEdge())
        sand.fill(Path(scene.rect(0, h, 1, 1 - h)), with: .linearGradient(Gradient(colors: [palette.sand.color, palette.sandDeep.color]),
                                                                          startPoint: scene.point(0.4, scene.waterline), endPoint: scene.point(0.6, 1)))
        var rng = SeededRandom(seed: scene.stableSeed &+ 41)
        for _ in 0..<420 {
            let x = rng.next(), y = rng.range(Double(scene.waterline) - 0.02, 1)
            let r = rng.range(0.6, 1.6) * Double(s)
            let light = rng.next() > 0.5
            let dot = Path(ellipseIn: CGRect(x: x * scene.size.width, y: y * scene.size.height, width: r, height: r))
            sand.fill(dot, with: .color(light ? .white.opacity(0.35) : palette.sandDeep.mix(palette.rock, 0.5).color(0.18)))
        }
        // Wet, glossy sand just below the edge, with a sky reflection.
        sand.fill(Path(scene.rect(0, scene.waterline - 0.03, 1, 0.09)), with: .linearGradient(
            Gradient(colors: [palette.wetSand.color(0.9), palette.wetSand.color(0)]),
            startPoint: scene.point(0.5, scene.waterline), endPoint: scene.point(0.5, scene.waterline + 0.06 * (1 - h) + 0.02)))
        var reflection = sand
        reflection.clip(to: scene.edgePath(offset: 0.014, closedToTop: true))
        reflection.fill(Path(scene.rect(0, h, 1, 1 - h)), with: .color(palette.skyMid.color(0.28)))
        // Re-draw rocks over the sand where they stand on the beach.
        for (rock, box) in scene.shallowsRocks {
            sand.fill(rock, with: .linearGradient(Gradient(colors: [palette.rockLight.color, palette.rock.color]),
                                                  startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY)))
        }
        if scene.region == .northAtlantic || scene.region == .southAtlanticMarsh { paintDunes(&context, scale: s) }

        // Foam: a soft wash, then lace, then bubbles.
        var wash = context
        wash.addFilter(.blur(radius: 3.5 * s))
        wash.stroke(scene.edgePath(offset: -0.004, closedToTop: false), with: .color(palette.foam.color(0.7)), lineWidth: 7 * s)
        context.stroke(scene.edgePath(closedToTop: false), with: .color(palette.foam.color(0.95)), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
        for (offset, alpha) in [(-0.012, 0.55), (-0.022, 0.35), (-0.034, 0.2)] as [(CGFloat, Double)] {
            context.stroke(scene.edgePath(offset: offset, closedToTop: false), with: .color(palette.foam.color(alpha)),
                           style: StrokeStyle(lineWidth: 1.1 * s, lineCap: .round, dash: [9 * s, 5 * s, 3 * s, 6 * s]))
        }
        var bubbles = SeededRandom(seed: scene.stableSeed &+ 53)
        for _ in 0..<70 {
            let x = CGFloat(bubbles.next())
            let y = scene.edge(at: x, offset: -CGFloat(bubbles.range(0, 0.03)))
            let r = CGFloat(bubbles.range(0.8, 2.2)) * s
            context.fill(Path(ellipseIn: CGRect(x: x * scene.size.width - r / 2, y: y * scene.size.height - r / 2, width: r, height: r)),
                         with: .color(palette.foam.color(bubbles.range(0.4, 0.85))))
        }
        // Foam rings where water meets rocks.
        for (rock, box) in scene.shallowsRocks where box.minY / scene.size.height < scene.waterline && box.maxY / scene.size.height > scene.waterline {
            var ring = context
            ring.clip(to: waterAbove)
            ring.stroke(rock, with: .color(palette.foam.color(0.6)), lineWidth: 1.4 * s)
        }
    }

    /// Light passing through shallow water: a soft network of bright lines.
    private func paintCaustics(_ context: inout GraphicsContext, scale: CGFloat) {
        var layer = context
        layer.addFilter(.blur(radius: 1.2 * scale))
        let top = scene.waterline - 0.11 * (1 - scene.horizon)
        for row in 0..<7 {
            var path = Path()
            let y0 = top + CGFloat(row) * 0.016 * (1 - scene.horizon) * 1.6
            path.move(to: scene.point(0, y0))
            stride(from: CGFloat(0.02), through: 1, by: 0.02).forEach { x in
                path.addLine(to: scene.point(x, y0 + 0.006 * sin(x * 38 + CGFloat(row) * 1.7) + 0.003 * sin(x * 91 + CGFloat(row))))
            }
            layer.stroke(path, with: .color(palette.turquoise.mix(RGB(0xFFFFFF), 0.5).color(0.28)), lineWidth: 1 * scale)
        }
    }

    /// Foreground dune with grass on the dry sand (bottom-left), framing the view.
    private func paintDunes(_ context: inout GraphicsContext, scale: CGFloat) {
        let h = scene.horizon
        let crest = h + (1 - h) * 0.80
        let dune = scene.smoothClosed([(-0.06, 1.04), (-0.04, crest + 0.02), (0.08, crest - 0.02), (0.22, crest), (0.36, crest + 0.06), (0.46, 1.04)])
        context.fill(dune, with: .linearGradient(Gradient(colors: [palette.sand.mix(RGB(0xFFFFFF), 0.3).color, palette.sandDeep.color]),
                                                 startPoint: scene.point(0.2, crest - 0.02), endPoint: scene.point(0.2, 1)))
        var rng = SeededRandom(seed: scene.stableSeed &+ 67)
        for _ in 0..<40 {
            let x = CGFloat(rng.range(-0.02, 0.36))
            let y = crest + CGFloat(rng.range(-0.01, 0.06)) + 0.04 * pow(abs(x - 0.1) / 0.3, 2)
            let height = CGFloat(rng.range(0.05, 0.13)), lean = CGFloat(rng.range(-0.035, 0.035))
            var blade = Path()
            blade.move(to: scene.point(x, y))
            blade.addQuadCurve(to: scene.point(x + lean, y - height), control: scene.point(x + lean * 0.15, y - height * 0.65))
            context.stroke(blade, with: .color(palette.vegetation.color(rng.range(0.55, 0.9))), style: StrokeStyle(lineWidth: rng.range(0.8, 1.5) * scale, lineCap: .round))
        }
    }
}

/// Fine film grain over the whole illustration.
struct GrainPainter {
    let scene: CoastScene
    let palette: ArtPalette

    func paint(_ context: inout GraphicsContext) {
        var rng = SeededRandom(seed: scene.stableSeed &+ 97)
        for _ in 0..<520 {
            let r = rng.range(0.5, 1.1) * Double(scene.scale)
            let dot = Path(CGRect(x: rng.next() * scene.size.width, y: rng.next() * scene.size.height, width: r, height: r))
            context.fill(dot, with: .color(rng.next() > 0.5 ? .white.opacity(palette.grainLight) : .black.opacity(palette.grainLight * 0.7)))
        }
    }
}

/// Single-colour outline of the scene for tinted/clear widget rendering.
struct CoastLinePainter {
    let scene: CoastScene

    func paint(_ context: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.color(.primary)
        let thin = max(0.8, scene.size.width / 260)
        var horizonLine = Path()
        horizonLine.move(to: scene.point(0, scene.horizon))
        horizonLine.addLine(to: scene.point(1, scene.horizon))
        context.stroke(horizonLine, with: ink, lineWidth: thin)
        context.stroke(scene.farLand, with: ink, lineWidth: thin)
        if let head = scene.nearHeadland { context.stroke(head, with: ink, lineWidth: thin) }
        context.stroke(scene.edgePath(closedToTop: false), with: ink, lineWidth: thin * 1.6)
        context.stroke(scene.edgePath(offset: -0.02, closedToTop: false), with: .color(.primary.opacity(0.5)), style: StrokeStyle(lineWidth: thin * 0.8, dash: [6, 4]))
        for (rock, _) in scene.shallowsRocks { context.stroke(rock, with: ink, lineWidth: thin) }
    }
}
