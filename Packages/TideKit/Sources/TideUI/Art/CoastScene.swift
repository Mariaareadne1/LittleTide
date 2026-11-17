import SwiftUI
import TideKit

/// Deterministic pseudo-random numbers so every render of a coast is identical.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    mutating func range(_ lower: Double, _ upper: Double) -> Double { lower + (upper - lower) * next() }
}

/// Geometry of one painted coast in unit coordinates, scaled to `size`.
struct CoastScene {
    let region: CoastRegion
    let size: CGSize
    /// 0 = lowest, 1 = highest water in the viewed range.
    let waterLevel: Double
    /// Fraction of the height above the horizon.
    let horizon: CGFloat

    /// Waterline on the beach at the lowest and highest level, relative to the
    /// space between horizon and bottom.
    static let waterlineLow: CGFloat = 0.40
    static let waterlineHigh: CGFloat = 0.66

    var seed: UInt64 { UInt64(abs(region.rawValue.hashValue) % 1_000_003) &* 7919 }
    var stableSeed: UInt64 {
        region.rawValue.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }

    var waterline: CGFloat {
        let t = Self.waterlineLow + (Self.waterlineHigh - Self.waterlineLow) * CGFloat(waterLevel)
        return horizon + (1 - horizon) * t
    }

    var scale: CGFloat { max(size.width, 1) / 400 }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height, width: w * size.width, height: h * size.height)
    }

    func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: point(first.0, first.1))
        points.dropFirst().forEach { path.addLine(to: point($0.0, $0.1)) }
        path.closeSubpath()
        return path
    }

    /// A smooth closed path through points (Catmull-Rom → Bézier).
    func smoothClosed(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        let pts = points.map { point($0.0, $0.1) }
        guard pts.count > 2 else { return path }
        path.move(to: pts[0])
        for i in 0..<pts.count {
            let p0 = pts[(i - 1 + pts.count) % pts.count], p1 = pts[i]
            let p2 = pts[(i + 1) % pts.count], p3 = pts[(i + 2) % pts.count]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    // MARK: Beach and water edge

    /// The sand body sits under the whole foreground; it is only visible below the water's edge.
    var beach: Path { Path(rect(0, horizon + (1 - horizon) * 0.2, 1, 1)) }

    /// Region below the water's edge (where dry and wet sand show).
    func belowEdge(offset: CGFloat = 0) -> Path {
        var path = edgePath(offset: offset, closedToTop: false)
        path.addLine(to: point(1, 1))
        path.addLine(to: point(0, 1))
        path.closeSubpath()
        return path
    }

    /// Organic water edge: the waterline perturbed by layered sines.
    func edge(at x: CGFloat, offset: CGFloat = 0) -> CGFloat {
        let w = waterline + offset
        let wobble = 0.006 * sin(x * 21 + 1.3) + 0.004 * sin(x * 47 + 0.4) + 0.0025 * sin(x * 93 + 2.1)
        // A gentle cove: the edge slants toward the viewer on the right and bows in the middle.
        let cove = (0.07 * (x - 0.5) - 0.035 * sin(.pi * x)) * (1 - horizon)
        return w + cove + wobble * (1 - horizon) * 2.2
    }

    func edgePath(offset: CGFloat = 0, closedToTop: Bool) -> Path {
        var path = Path()
        if closedToTop {
            path.move(to: point(0, horizon))
            path.addLine(to: point(0, edge(at: 0, offset: offset)))
        } else {
            path.move(to: point(0, edge(at: 0, offset: offset)))
        }
        stride(from: CGFloat(0.01), through: 1.0001, by: 0.01).forEach { path.addLine(to: point($0, edge(at: $0, offset: offset))) }
        if closedToTop {
            path.addLine(to: point(1, horizon))
            path.closeSubpath()
        }
        return path
    }

    // MARK: Land

    var farLand: Path {
        let h = horizon
        switch region {
        case .northernPacific:
            var path = polygon([(0.46, h), (0.52, h - 0.04), (0.60, h - 0.09), (0.70, h - 0.13), (0.82, h - 0.17), (0.92, h - 0.21), (1, h - 0.23), (1, h)])
            path.addPath(polygon([(0.33, h), (0.335, h - 0.07), (0.35, h - 0.08), (0.37, h - 0.06), (0.375, h)]))
            path.addPath(polygon([(0.40, h), (0.405, h - 0.04), (0.42, h - 0.045), (0.425, h)]))
            return path
        case .southernCalifornia:
            return polygon([(0.55, h), (0.62, h - 0.035), (0.74, h - 0.06), (0.86, h - 0.075), (1, h - 0.085), (1, h)])
        case .northAtlantic:
            var path = polygon([(0, h - 0.03), (0.15, h - 0.026), (0.32, h - 0.015), (0.5, h - 0.006), (0.56, h), (0, h)])
            path.addPath(polygon([(0.11, h - 0.028), (0.114, h - 0.095), (0.124, h - 0.095), (0.128, h - 0.028)]))
            return path
        case .southAtlanticMarsh:
            let bumps: [(CGFloat, CGFloat)] = stride(from: CGFloat(0), through: 1, by: 0.03).map { x in (x, h - 0.022 - 0.01 * abs(sin(x * 27))) }
            return polygon([(0, h)] + bumps + [(1, h)])
        case .gulfShore:
            return polygon([(0, h), (0, h - 0.012), (0.42, h - 0.006), (0.62, h)])
        case .tropicalIsland:
            var path = polygon([(0.2, h), (0.34, h - 0.1), (0.45, h - 0.2), (0.5, h - 0.215), (0.56, h - 0.18), (0.7, h - 0.07), (0.82, h)])
            path.addPath(polygon([(0.64, h), (0.76, h - 0.06), (0.88, h - 0.08), (1, h - 0.05), (1, h)]))
            return path
        case .northernFjord:
            return polygon([(0, h), (0, h - 0.15), (0.1, h - 0.24), (0.18, h - 0.14), (0.29, h - 0.28), (0.41, h - 0.13),
                            (0.53, h - 0.21), (0.63, h - 0.1), (0.75, h - 0.19), (0.87, h - 0.11), (1, h - 0.17), (1, h)])
        }
    }

    /// A darker, closer headland that frames the cove (Pacific and tropical coasts).
    var nearHeadland: Path? {
        let h = horizon
        switch region {
        case .northernPacific:
            return polygon([(1.0, h - 0.2), (0.95, h - 0.17), (0.9, h - 0.1), (0.86, h - 0.06), (0.83, h - 0.01), (0.8, h + 0.03),
                            (0.81, h + 0.06), (0.86, h + 0.1), (0.93, h + 0.14), (1.0, h + 0.17)])
        case .tropicalIsland:
            return smoothClosed([(1.02, h - 0.01), (0.92, h + 0.02), (0.88, h + 0.08), (1.02, h + 0.12)])
        default:
            return nil
        }
    }

    var snowCaps: Path {
        guard region == .northernFjord else { return Path() }
        let h = horizon
        var path = polygon([(0.08, h - 0.22), (0.1, h - 0.24), (0.125, h - 0.215)])
        path.addPath(polygon([(0.26, h - 0.25), (0.29, h - 0.28), (0.325, h - 0.245)]))
        path.addPath(polygon([(0.5, h - 0.19), (0.53, h - 0.21), (0.555, h - 0.188)]))
        return path
    }

    /// Rocks or pilings standing in the shallows; a rising tide covers them.
    var shallowsRocks: [(Path, CGRect)] {
        let top = horizon + (1 - horizon) * 0.48
        switch region {
        case .northernPacific, .tropicalIsland, .southernCalifornia:
            let specs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = region == .southernCalifornia
                ? [(0.70, 0.10, 0.09, 0.05), (0.80, 0.18, 0.06, 0.035)]
                : [(0.62, 0.06, 0.12, 0.09), (0.74, 0.14, 0.07, 0.05), (0.84, 0.2, 0.1, 0.06), (0.55, 0.22, 0.05, 0.03)]
            return specs.map { x, yOffset, w, hgt in
                let y = top + (1 - horizon) * yOffset
                let box = rect(x, y, w, hgt)
                let rock = smoothClosed([(x, y + hgt), (x + w * 0.1, y + hgt * 0.35), (x + w * 0.35, y), (x + w * 0.7, y + hgt * 0.12),
                                         (x + w, y + hgt * 0.6), (x + w * 0.95, y + hgt)])
                return (rock, box)
            }
        case .gulfShore:
            return [0.6, 0.67, 0.74, 0.81, 0.88].enumerated().map { index, x in
                let y = horizon + (1 - horizon) * (0.26 + CGFloat(index) * 0.025)
                let box = rect(x, y, 0.012, 1 - y - 0.12)
                return (Path(roundedRect: box, cornerRadius: 1.5 * scale), box)
            }
        case .northernFjord:
            let y = horizon + (1 - horizon) * 0.62
            let box = rect(0.58, y, 0.24, 0.02)
            return [(Path(roundedRect: box, cornerRadius: 3 * scale), box)]
        case .northAtlantic, .southAtlanticMarsh:
            return []
        }
    }
}
