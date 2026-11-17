import Foundation

/// Deterministic gradient noise, fractal noise and cellular (Worley) noise.
struct Noise {
    private let perm: [Int]

    init(seed: UInt64) {
        var rng = SplitMix(seed: seed)
        var p = Array(0..<256)
        for i in stride(from: 255, to: 0, by: -1) { p.swapAt(i, Int(rng.next() % UInt64(i + 1))) }
        perm = p + p
    }

    private func grad(_ hash: Int, _ x: Float, _ y: Float) -> Float {
        switch hash & 7 {
        case 0: return x + y
        case 1: return -x + y
        case 2: return x - y
        case 3: return -x - y
        case 4: return x
        case 5: return -x
        case 6: return y
        default: return -y
        }
    }

    private func fade(_ t: Float) -> Float { t * t * t * (t * (t * 6 - 15) + 10) }

    /// Perlin noise in roughly [-1, 1].
    func perlin(_ x: Float, _ y: Float) -> Float {
        let xf = floor(x), yf = floor(y)
        let xi = Int(xf) & 255, yi = Int(yf) & 255
        let dx = x - xf, dy = y - yf
        let u = fade(dx), v = fade(dy)
        let aa = perm[perm[xi] + yi], ab = perm[perm[xi] + yi + 1]
        let ba = perm[perm[xi + 1] + yi], bb = perm[perm[xi + 1] + yi + 1]
        let x1 = lerp(grad(aa, dx, dy), grad(ba, dx - 1, dy), u)
        let x2 = lerp(grad(ab, dx, dy - 1), grad(bb, dx - 1, dy - 1), u)
        return lerp(x1, x2, v) * 0.7
    }

    func fbm(_ x: Float, _ y: Float, octaves: Int = 5) -> Float {
        var sum: Float = 0, amp: Float = 0.5, freq: Float = 1
        for _ in 0..<octaves {
            sum += amp * perlin(x * freq, y * freq)
            freq *= 2.03
            amp *= 0.5
        }
        return sum
    }

    /// Distance to the nearest jittered cell point (F1), in cell units.
    func cellPoint(_ x: Float, _ y: Float) -> Float {
        let cx = Int(floor(x)), cy = Int(floor(y))
        var f1: Float = 9
        for j in -1...1 {
            for i in -1...1 {
                let gx = cx + i, gy = cy + j
                let h = perm[(perm[gx & 255] + (gy & 255)) & 511]
                let h2 = perm[(h + 37) & 511]
                let px = Float(gx) + 0.15 + 0.7 * Float(h) / 255
                let py = Float(gy) + 0.15 + 0.7 * Float(h2) / 255
                f1 = min(f1, hypot(px - x, py - y))
            }
        }
        return f1
    }

    /// Distance to the nearest cell edge (F2 − F1) for a jittered grid, in cell units.
    func cellEdge(_ x: Float, _ y: Float) -> Float {
        let cx = Int(floor(x)), cy = Int(floor(y))
        var f1: Float = 9, f2: Float = 9
        for j in -1...1 {
            for i in -1...1 {
                let gx = cx + i, gy = cy + j
                let h = perm[(perm[gx & 255] + (gy & 255)) & 511]
                let h2 = perm[(h + 37) & 511]
                let px = Float(gx) + 0.15 + 0.7 * Float(h) / 255
                let py = Float(gy) + 0.15 + 0.7 * Float(h2) / 255
                let d = hypot(px - x, py - y)
                if d < f1 { f2 = f1; f1 = d } else if d < f2 { f2 = d }
            }
        }
        return f2 - f1
    }
}

struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
    mutating func range(_ a: Float, _ b: Float) -> Float { a + (b - a) * unit() }
}

@inline(__always) func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
@inline(__always) func clamp01(_ x: Float) -> Float { min(max(x, 0), 1) }
@inline(__always) func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = clamp01((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t)
}

struct RGB {
    var r: Float, g: Float, b: Float
    init(_ hex: UInt32) {
        r = Float((hex >> 16) & 0xFF) / 255; g = Float((hex >> 8) & 0xFF) / 255; b = Float(hex & 0xFF) / 255
    }
    init(r: Float, g: Float, b: Float) { self.r = r; self.g = g; self.b = b }
    func mix(_ o: RGB, _ t: Float) -> RGB { RGB(r: lerp(r, o.r, t), g: lerp(g, o.g, t), b: lerp(b, o.b, t)) }
    func scaled(_ k: Float) -> RGB { RGB(r: r * k, g: g * k, b: b * k) }
    static func + (a: RGB, b: RGB) -> RGB { RGB(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b) }
    static func * (a: RGB, b: RGB) -> RGB { RGB(r: a.r * b.r, g: a.g * b.g, b: a.b * b.b) }
}

/// A colour ramp sampled at t ∈ [0, 1].
struct Ramp {
    let stops: [(Float, RGB)]
    func at(_ t: Float) -> RGB {
        let t = clamp01(t)
        guard let first = stops.first else { return RGB(0) }
        if t <= first.0 { return first.1 }
        for i in 1..<stops.count where t <= stops[i].0 {
            let (t0, c0) = stops[i - 1], (t1, c1) = stops[i]
            return c0.mix(c1, (t - t0) / max(t1 - t0, 0.0001))
        }
        return stops.last!.1
    }
}
