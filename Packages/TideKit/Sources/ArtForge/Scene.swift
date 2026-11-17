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
    /// Height gained landward of `duneStart` (dunes, or a bluff when steep).
    var landRise: Float = 0.22
    /// Width (in s) over which the land rises; small = steep bluff.
    var riseWidth: Float = 0.18
    var grassTufts: Int = 1500
    /// Kelp canopy painted into the water layer (Northern California).
    var kelp: [RGB] = []
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

extension SceneSpec {
    /// Northern California / Pacific Northwest: a dark rocky pocket cove, cold deep water,
    /// kelp beds and many boulders. Representative, not a map.
    static let norCal = SceneSpec(
        name: "norCal", width: 1080, height: 2340, seed: 0x9F0C4,
        shore: { v in -0.28 + 2.2 * v * (1 - v) + 0.08 * sin(v * 12 + 0.4) + 0.03 * sin(v * 27 + 2) },
        beachSlope: 0.85,
        duneStart: -0.12,
        sandbars: [(0.08, 0.03, 0.02)],
        boulders: [(0.18, 0.12, 0.12, 0.66), (0.42, 0.2, 0.07, 0.6), (0.6, 0.3, 0.09, 0.62), (0.78, 0.18, 0.06, 0.58),
                   (0.88, 0.42, 0.11, 0.64), (0.55, 0.5, 0.05, 0.56), (0.72, 0.62, 0.08, 0.6), (0.3, 0.7, 0.1, 0.65),
                   (0.12, 0.82, 0.13, 0.67), (0.48, 0.86, 0.06, 0.57)],
        sand: Ramp(stops: [(0, RGB(0xBFAE8E)), (0.45, RGB(0xCDBC9C)), (0.8, RGB(0xB5A281)), (1, RGB(0xA4906F))]),
        seabedTint: RGB(0x8FC2BC),
        water: Ramp(stops: [(0, RGB(0x4FA9AA)), (0.1, RGB(0x2E8E98)), (0.25, RGB(0x1E7184)), (0.45, RGB(0x165A70)), (0.7, RGB(0x10475D)), (1, RGB(0x0B3A4E))]),
        turquoise: RGB(0x79C4BC),
        foam: RGB(0xF2F4F0),
        rockDark: RGB(0x2A2E2D), rockLight: RGB(0x8A8C84),
        grass: [RGB(0x6F7B4A), RGB(0x55603A), RGB(0x8A8F5C)],
        wetDarkening: 0.34,
        landRise: 0.3, riseWidth: 0.08, grassTufts: 900,
        kelp: [RGB(0x4E4A22), RGB(0x645C2A), RGB(0x3E3D1E)]
    )

    /// Southern California: warm sand below a bluff, bright turquoise water, rocky reefs
    /// visible through the shallows. Representative, not a map.
    static let soCal = SceneSpec(
        name: "soCal", width: 1080, height: 2340, seed: 0x5CA1,
        shore: { v in -0.14 + 2.3 * v * (1 - v) + 0.04 * sin(v * 7 + 2.2) + 0.015 * sin(v * 19 + 0.7) },
        beachSlope: 0.55,
        duneStart: -0.3,
        sandbars: [(0.11, 0.04, 0.03), (0.24, 0.05, 0.022)],
        // Reefs: rock tops well below low water, seen as dark patches through the shallows.
        boulders: [(0.66, 0.28, 0.09, 0.29), (0.8, 0.4, 0.12, 0.3), (0.72, 0.56, 0.08, 0.28), (0.9, 0.22, 0.07, 0.3),
                   (0.62, 0.72, 0.1, 0.29), (0.86, 0.8, 0.08, 0.3)],
        sand: Ramp(stops: [(0, RGB(0xEDD0A2)), (0.45, RGB(0xF5DFB8)), (0.8, RGB(0xEBC896)), (1, RGB(0xDDB582))]),
        seabedTint: RGB(0xB2E6D9),
        water: Ramp(stops: [(0, RGB(0x6BD3C8)), (0.1, RGB(0x45BEC0)), (0.25, RGB(0x2AA2B3)), (0.45, RGB(0x1C88A0)), (0.7, RGB(0x146F8C)), (1, RGB(0x105B78))]),
        turquoise: RGB(0x9BE6D7),
        foam: RGB(0xFBF9F1),
        rockDark: RGB(0x4A4136), rockLight: RGB(0xB09474),
        grass: [RGB(0x8F9466), RGB(0x7A7F55), RGB(0xA7A27A), RGB(0x6E744B)],
        wetDarkening: 0.26,
        landRise: 0.34, riseWidth: 0.06, grassTufts: 2200
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
                    let rise = smoothstep(spec.duneStart, spec.duneStart - spec.riseWidth, s)
                    hgt += spec.landRise * rise * (0.6 + 0.6 * noise.fbm(u * 6 + 3, v * 6 * aspect / 2))
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
