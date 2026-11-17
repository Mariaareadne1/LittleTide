import CoreGraphics
import Foundation

/// An RGB float image with brush-stroke painting via CoreGraphics.
struct Canvas {
    let width: Int, height: Int
    var pixels: [UInt8]   // RGBA8, premultiplied (opaque)

    init(width: Int, height: Int, fill: (Int, Int) -> RGB) {
        self.width = width; self.height = height
        pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let c = fill(x, y), i = (y * width + x) * 4
            pixels[i] = UInt8(clamp01(c.r) * 255); pixels[i + 1] = UInt8(clamp01(c.g) * 255); pixels[i + 2] = UInt8(clamp01(c.b) * 255)
        } }
    }

    /// Paints strokes; `strokes` receives a context in top-left pixel coordinates.
    mutating func paint(_ strokes: (CGContext) -> Void) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            ctx.setLineCap(.round)
            strokes(ctx)
        }
    }

    func rgb(_ x: Int, _ y: Int) -> RGB {
        let i = (min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)) * 4
        return RGB(r: Float(pixels[i]) / 255, g: Float(pixels[i + 1]) / 255, b: Float(pixels[i + 2]) / 255)
    }
}

extension CGContext {
    func stroke(from a: CGPoint, bend: CGPoint, to b: CGPoint, color: RGB, alpha: Float, width: CGFloat) {
        setStrokeColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: CGFloat(alpha))
        setLineWidth(width)
        beginPath(); move(to: a); addQuadCurve(to: b, control: bend); strokePath()
    }
}

/// Builds every layer of one scene.
struct LayerPainter {
    let terrain: Terrain
    var spec: SceneSpec { terrain.spec }
    var noise: Noise { terrain.noise }

    /// Unit tangent of the shoreline (pixel space) near row y.
    func shoreTangent(_ y: Int) -> (Float, Float) {
        let v = Float(y) / Float(spec.height - 1), dv: Float = 0.002
        let du = (spec.shore(v + dv) - spec.shore(v - dv)) / (2 * dv)
        let tx = du * Float(spec.width), ty = Float(spec.height)
        let n = hypot(tx, ty)
        return (tx / n, ty / n)
    }

    /// Unit tangent of the local depth contour at (x, y).
    func contourTangent(_ x: Int, _ y: Int) -> (Float, Float) {
        let gx = terrain.sample(terrain.across, x + 3, y) - terrain.sample(terrain.across, x - 3, y)
        let gy = terrain.sample(terrain.across, x, y + 3) - terrain.sample(terrain.across, x, y - 3)
        let n = max(hypot(gx, gy), 1e-6)
        return (-gy / n, gx / n)
    }

    func normalShade(_ x: Int, _ y: Int, strength: Float) -> Float {
        let hL = terrain.sample(terrain.heights, x - 2, y), hR = terrain.sample(terrain.heights, x + 2, y)
        let hU = terrain.sample(terrain.heights, x, y - 2), hD = terrain.sample(terrain.heights, x, y + 2)
        let nx = (hL - hR) * strength, ny = (hU - hD) * strength
        let n = (nx, ny, Float(1)), len = sqrt(n.0 * n.0 + n.1 * n.1 + 1)
        let light: (Float, Float, Float) = (-0.55, -0.6, 0.58)
        return max(0, (n.0 * light.0 + n.1 * light.1 + n.2 * light.2) / len)
    }

    // MARK: Land: sand, dunes, grass, rocks (also the seabed seen through shallows)

    /// `includeFigures: false` paints the same land without people (used for the app icon).
    func land(includeFigures: Bool = true) -> Canvas {
        let w = spec.width, h = spec.height
        var canvas = Canvas(width: w, height: h) { x, y in
            let i = y * w + x, s = terrain.across[i]
            let u = Float(x) / Float(w), v = Float(y) / Float(h)
            var c = spec.sand.at(0.5 + 0.45 * noise.fbm(u * 7, v * 15, octaves: 4))
            // Relief shading on dunes and sand.
            let shade = normalShade(x, y, strength: 140)
            c = c.scaled(0.84 + 0.22 * shade)
            // Underwater sand ripples (seen through the shallows).
            if s > 0 {
                let (tx, ty) = shoreTangent(y)
                let along = (Float(x) * tx + Float(y) * ty) * 0.0
                let ripple = sin((Float(x) * ty - Float(y) * tx) * 0.09 + along + 4 * noise.perlin(u * 12, v * 24))
                c = c.scaled(0.985 + 0.015 * ripple)
            }
            // Rocks: shaded boulders with speckle.
            let rock = terrain.rockMask[i]
            if rock > 0 {
                let lit = normalShade(x, y, strength: 60)
                var rc = spec.rockDark.mix(spec.rockLight, clamp01(lit * 1.25 - 0.1))
                rc = rc.scaled(0.9 + 0.2 * noise.perlin(u * 160, v * 340))
                c = c.mix(rc, rock)
            }
            return c
        }
        var rng = SplitMix(seed: spec.seed &+ 1)
        canvas.paint { ctx in
            // Sand strokes along the shore.
            for _ in 0..<14000 {
                let x = Int(rng.unit() * Float(w)), y = Int(rng.unit() * Float(h))
                let i = y * w + x
                guard terrain.rockMask[i] < 0.1 else { continue }
                let (tx, ty) = shoreTangent(y)
                let len = rng.range(5, 18), wid = CGFloat(rng.range(1.2, 3.2))
                let base = spec.sand.at(rng.unit()).scaled(rng.range(0.92, 1.06))
                let a = CGPoint(x: CGFloat(Float(x) - tx * len / 2), y: CGFloat(Float(y) - ty * len / 2))
                let b = CGPoint(x: CGFloat(Float(x) + tx * len / 2), y: CGFloat(Float(y) + ty * len / 2))
                ctx.stroke(from: a, bend: CGPoint(x: (a.x + b.x) / 2 + CGFloat(rng.range(-2, 2)), y: (a.y + b.y) / 2), to: b,
                           color: base, alpha: rng.range(0.12, 0.3), width: wid)
            }
            if includeFigures { paintFigures(ctx, scale: 2.6) }
            // Dune grass: tufts of blades on the high dunes.
            for _ in 0..<spec.grassTufts {
                let x = Int(rng.unit() * Float(w)), y = Int(rng.unit() * Float(h))
                let i = y * w + x
                let s = terrain.across[i]
                guard s < spec.duneStart - 0.02, rng.unit() < smoothstep(spec.duneStart - 0.02, spec.duneStart - 0.12, s) else { continue }
                let blades = Int(rng.range(4, 10))
                for _ in 0..<blades {
                    let len = rng.range(10, 30), lean = rng.range(-0.8, 0.8)
                    let a = CGPoint(x: CGFloat(x) + CGFloat(rng.range(-4, 4)), y: CGFloat(y))
                    let b = CGPoint(x: a.x + CGFloat(lean * len * 0.6), y: a.y - CGFloat(len))
                    let color = spec.grass[Int(rng.unit() * Float(spec.grass.count)) % spec.grass.count].scaled(rng.range(0.85, 1.15))
                    ctx.stroke(from: a, bend: CGPoint(x: (a.x + b.x) / 2 + CGFloat(lean * 4), y: (a.y + b.y) / 2), to: b,
                               color: color, alpha: rng.range(0.55, 0.9), width: CGFloat(rng.range(1, 2.4)))
                }
            }
        }
        return canvas
    }

    // MARK: Water colour: painterly tonal bands along depth contours

    func water(includeCraft: Bool = true) -> Canvas {
        let w = spec.width, h = spec.height
        let bands: Float = 6
        var canvas = Canvas(width: w, height: h) { x, y in
            let i = y * w + x
            let u = Float(x) / Float(w), v = Float(y) / Float(h)
            let s = terrain.across[i]
            let t = clamp01(s / 0.7) + 0.06 * noise.fbm(u * 4 + 7, v * 8, octaves: 4)
            // Soft posterisation into painted bands, boundaries warped by noise.
            let q = t * bands + 0.35 * noise.fbm(u * 9 + 3, v * 18 + 1, octaves: 3)
            let band = floor(q), f = q - band
            let soft = smoothstep(0.78, 1.0, f)
            let tq = clamp01((band + soft) / bands)
            var c = spec.water.at(tq)
            // Swirls of lighter and darker water.
            let swirl = noise.fbm(u * 3 + 21, v * 6 + 5, octaves: 4)
            c = c.scaled(1 - 0.1 * smoothstep(0.12, 0.38, swirl) + 0.08 * smoothstep(-0.15, -0.4, swirl))
            return c
        }
        var rng = SplitMix(seed: spec.seed &+ 2)
        canvas.paint { ctx in
            // Broad soft brush strokes along the contours.
            for _ in 0..<9000 {
                let x = Int(rng.unit() * Float(w)), y = Int(rng.unit() * Float(h))
                let s = terrain.across[y * w + x]
                guard s > -0.02 else { continue }
                let (tx, ty) = contourTangent(x, y)
                let len = rng.range(30, 110)
                let t = clamp01(s / 0.7) + rng.range(-0.06, 0.06)
                let color = spec.water.at(t).scaled(rng.range(0.9, 1.1))
                let a = CGPoint(x: CGFloat(Float(x) - tx * len / 2), y: CGFloat(Float(y) - ty * len / 2))
                let b = CGPoint(x: CGFloat(Float(x) + tx * len / 2), y: CGFloat(Float(y) + ty * len / 2))
                let bow = CGFloat(rng.range(-0.2, 0.2) * len)
                ctx.stroke(from: a, bend: CGPoint(x: (a.x + b.x) / 2 + CGFloat(ty) * bow, y: (a.y + b.y) / 2 - CGFloat(tx) * bow), to: b,
                           color: color, alpha: rng.range(0.12, 0.3), width: CGFloat(rng.range(5, 14)))
            }
            // Kelp canopy: clumps of olive fronds floating offshore.
            if !spec.kelp.isEmpty {
                for _ in 0..<14000 {
                    let x = Int(rng.unit() * Float(w)), y = Int(rng.unit() * Float(h))
                    let s = terrain.across[y * w + x]
                    let u = Float(x) / Float(w), v = Float(y) / Float(h)
                    let bed = smoothstep(-0.05, 0.2, noise.fbm(u * 3 + 70, v * 6 + 11, octaves: 4))
                    guard s > 0.16, s < 0.6, rng.unit() < bed else { continue }
                    let (tx, ty) = contourTangent(x, y)
                    let len = rng.range(10, 34)
                    let color = spec.kelp[Int(rng.unit() * Float(spec.kelp.count)) % spec.kelp.count].scaled(rng.range(0.85, 1.15))
                    let a = CGPoint(x: CGFloat(Float(x) - tx * len / 2), y: CGFloat(Float(y) - ty * len / 2))
                    let b = CGPoint(x: CGFloat(Float(x) + tx * len / 2), y: CGFloat(Float(y) + ty * len / 2))
                    ctx.stroke(from: a, bend: CGPoint(x: (a.x + b.x) / 2 + CGFloat(rng.range(-5, 5)), y: (a.y + b.y) / 2), to: b,
                               color: color, alpha: rng.range(0.4, 0.8), width: CGFloat(rng.range(2.5, 6)))
                }
            }
            if includeCraft { paintCraft(ctx, scale: 1.8) }
            // Thin light lines on the swell and scattered foam streaks offshore.
            for _ in 0..<1400 {
                let x = Int(rng.unit() * Float(w)), y = Int(rng.unit() * Float(h))
                let s = terrain.across[y * w + x]
                guard s > 0.04 else { continue }
                let (tx, ty) = contourTangent(x, y)
                let len = rng.range(60, 170)
                let color = spec.water.at(clamp01(s / 0.7)).mix(RGB(0xEFFBF8), rng.range(0.3, 0.6))
                let a = CGPoint(x: CGFloat(Float(x) - tx * len / 2), y: CGFloat(Float(y) - ty * len / 2))
                let b = CGPoint(x: CGFloat(Float(x) + tx * len / 2), y: CGFloat(Float(y) + ty * len / 2))
                let bow = CGFloat(rng.range(-0.25, 0.25) * len)
                ctx.stroke(from: a, bend: CGPoint(x: (a.x + b.x) / 2 + CGFloat(ty) * bow, y: (a.y + b.y) / 2 - CGFloat(tx) * bow), to: b,
                           color: color, alpha: rng.range(0.06, 0.2), width: CGFloat(rng.range(1.5, 4)))
            }
        }
        return canvas
    }

    // MARK: Foam lace (greyscale)

    /// Low-frequency field (−1…1) that makes foam ribbons wander off the depth contours.
    func wander() -> [Float] {
        let w = spec.width, h = spec.height
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w {
            out[y * w + x] = noise.fbm(Float(x) / 170 + 40, Float(y) / 170 + 9, octaves: 4) * 1.8
        } }
        return out
    }

    func foam() -> [Float] {
        let w = spec.width, h = spec.height
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w {
            let fx = Float(x), fy = Float(y)
            // Foam is white with round bubble holes: high away from cell points.
            let b1 = smoothstep(0.18, 0.42, noise.cellPoint(fx / 22, fy / 22))
            let b2 = smoothstep(0.2, 0.45, noise.cellPoint(fx / 9 + 50, fy / 9 + 50))
            let breakup = smoothstep(-0.3, 0.25, noise.fbm(fx / 130, fy / 130, octaves: 3))
            out[y * w + x] = clamp01(b1 * (0.55 + 0.45 * b2) * (0.55 + 0.45 * breakup))
        } }
        return out
    }
}
