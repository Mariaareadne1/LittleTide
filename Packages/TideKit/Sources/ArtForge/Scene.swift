import Foundation

/// A designed coast seen from above. Heights: 0 = deep water … 1 = dune crest.
/// The tide level `L` (see `Composite.levelRange`) decides what is wet.
struct SceneSpec {
    let name: String
    let width: Int
    let height: Int
    let seed: UInt64
    /// Across-shore position of the mean shoreline at vertical position v (0 top … 1 bottom).
    let shore: (Float) -> Float
    let beachSlope: Float
    let duneStart: Float          // s below which dunes rise (negative = landward)
    let sandbars: [(offset: Float, width: Float, height: Float)]
    let boulders: [(u: Float, v: Float, radius: Float, top: Float)]
    let sand: Ramp
    let seabedTint: RGB
    let water: Ramp               // by offshore distance
    let turquoise: RGB
    let foam: RGB
    let rockDark: RGB
    let rockLight: RGB
    let grass: [RGB]
    let wetDarkening: Float
}

extension SceneSpec {
    /// Cape Cod–style outer beach: pale sand, grassy dunes, a few glacial boulders,
    /// sandbars that break into lines of foam. Original, representative, not a map.
    static let eastCoast = SceneSpec(
        name: "eastCoast", width: 1080, height: 2340, seed: 0xC0A57,
        // A sandy point bulging from the left; sea fills the top-right and the whole bottom,
        // so the title and tide card always sit over water.
        shore: { v in -0.2 + 2.6 * v * (1 - v) + 0.05 * sin(v * 9 + 1.2) + 0.02 * sin(v * 21 + 0.3) },
        beachSlope: 0.62,
        duneStart: -0.34,
        sandbars: [(0.10, 0.035, 0.035), (0.21, 0.05, 0.03), (0.34, 0.06, 0.022)],
        boulders: [(0.66, 0.2, 0.06, 0.6), (0.92, 0.33, 0.1, 0.625), (0.7, 0.47, 0.04, 0.555), (0.86, 0.58, 0.055, 0.57)],
        sand: Ramp(stops: [(0, RGB(0xEACFA8)), (0.45, RGB(0xF3DFBF)), (0.8, RGB(0xE8CCA4)), (1, RGB(0xDDBE93))]),
        seabedTint: RGB(0xA6DCD2),
        water: Ramp(stops: [(0, RGB(0x62C7C0)), (0.1, RGB(0x3FB2B5)), (0.25, RGB(0x2A9BA8)), (0.45, RGB(0x1E8597)), (0.7, RGB(0x166D84)), (1, RGB(0x115A73))]),
        turquoise: RGB(0x8EDDD1),
        foam: RGB(0xF7F6EE),
        rockDark: RGB(0x37332F), rockLight: RGB(0xA1896A),
        grass: [RGB(0x8E9A5A), RGB(0x6F7D45), RGB(0xA6A867), RGB(0x5E6B3E)],
        wetDarkening: 0.3
    )
}

/// The terrain, plus per-pixel helpers used by every layer.
struct Terrain {
    let spec: SceneSpec
    let noise: Noise
    var heights: [Float]
    var rockMask: [Float]
    var across: [Float]   // across-shore distance s (positive seaward)

    init(spec: SceneSpec) {
        self.spec = spec
        noise = Noise(seed: spec.seed)
        let w = spec.width, h = spec.height
        heights = [Float](repeating: 0, count: w * h)
        rockMask = [Float](repeating: 0, count: w * h)
        across = [Float](repeating: 0, count: w * h)
        let aspect = Float(h) / Float(w)
        for y in 0..<h {
            let v = Float(y) / Float(h - 1)
            for x in 0..<w {
                let u = Float(x) / Float(w - 1)
                // Domain-warped shoreline: organic, never a straight edge.
                let warp = 0.06 * noise.fbm(u * 2.4 + 11, v * 2.4 * aspect / 2.2, octaves: 5)
                let s = (u - spec.shore(v)) + warp
                var hgt = 0.5 - spec.beachSlope * s
                for bar in spec.sandbars {
                    let wobble = 0.02 * noise.fbm(v * 9 + bar.offset * 50, u * 2)
                    let d = (s - bar.offset - wobble) / bar.width
                    hgt += bar.height * exp(-d * d)
                }
                if s < spec.duneStart {
                    let rise = smoothstep(spec.duneStart, spec.duneStart - 0.18, s)
                    hgt += 0.22 * rise * (0.6 + 0.6 * noise.fbm(u * 6 + 3, v * 6 * aspect / 2))
                }
                hgt += 0.010 * noise.fbm(u * 14, v * 14 * aspect / 2.2)
                hgt += 0.004 * noise.perlin(u * 90, v * 90 * aspect / 2.2)
                var rock: Float = 0
                for b in spec.boulders {
                    let du = (u - b.u), dv = (v - b.v) * aspect
                    // Irregular, slightly flattened boulder outlines.
                    let angle = atan2(dv, du)
                    let lobes = 0.22 * sin(angle * 3 + b.u * 20) + 0.12 * sin(angle * 5 + b.v * 30)
                    let r = b.radius * (1 + lobes + 0.3 * noise.fbm(u * 14 + b.u * 40, v * 14 * aspect / 2.2 + b.v * 40))
                    let d = hypot(du * 0.8, dv * 1.15) / r
                    if d < 1.25 {
                        let dome = max(0, 1 - d * d)
                        let top = b.top * pow(dome, 0.3) + 0.014 * noise.perlin(u * 120, v * 120)
                        if top > hgt { hgt = top; rock = max(rock, smoothstep(1.02, 0.9, d)) }
                    }
                }
                let i = y * w + x
                heights[i] = hgt
                rockMask[i] = rock
                across[i] = s
            }
        }
    }

    func sample(_ field: [Float], _ x: Int, _ y: Int) -> Float {
        let xx = min(max(x, 0), spec.width - 1), yy = min(max(y, 0), spec.height - 1)
        return field[yy * spec.width + xx]
    }
}
