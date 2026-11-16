import SwiftUI
import TideKit

/// Original, procedurally drawn coastal illustration. Representative of a *kind* of
/// coast, never a specific beach. `waterLevel` (0 = lowest, 1 = highest predicted water
/// in the viewed window) moves the waterline up or down a fixed, abstract beach slope.
public struct CoastArtView: View {
    public enum Style: Sendable {
        /// Full-colour painted layers.
        case painted
        /// Single-colour line drawing, for tinted/clear widget rendering.
        case line
    }

    let region: CoastRegion
    let waterLevel: Double
    let style: Style
    @Environment(\.colorScheme) private var colorScheme

    public init(region: CoastRegion, waterLevel: Double = 0.5, style: Style = .painted) {
        self.region = region
        self.waterLevel = min(max(waterLevel, 0), 1)
        self.style = style
    }

    public var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let scene = CoastScene(region: region, size: size, waterLevel: waterLevel)
            switch style {
            case .painted:
                scene.paint(in: &context, palette: .make(region, dark: colorScheme == .dark))
            case .line:
                scene.outline(in: &context)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Illustration: \(region.illustrationDescription). Representative, not a live view.")
        .accessibilityAddTraits(.isImage)
    }
}

/// Geometry of one illustration, in a unit coordinate space scaled to `size`.
struct CoastScene {
    let region: CoastRegion
    let size: CGSize
    let waterLevel: Double

    static let horizon: CGFloat = 0.5
    /// Waterline height on the beach at the lowest and highest level.
    static let waterlineAtLow: CGFloat = 0.64
    static let waterlineAtHigh: CGFloat = 0.82

    var waterline: CGFloat {
        Self.waterlineAtLow + (Self.waterlineAtHigh - Self.waterlineAtLow) * CGFloat(waterLevel)
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }

    func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: point(first.0, first.1))
        points.dropFirst().forEach { path.addLine(to: point($0.0, $0.1)) }
        path.closeSubpath()
        return path
    }

    // MARK: Shapes

    var skyRect: Path { Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * Self.horizon)) }
    var seaRect: Path {
        Path(CGRect(x: 0, y: size.height * Self.horizon, width: size.width, height: size.height * (1 - Self.horizon)))
    }

    /// Beach surface: higher on the left, sloping into the sea on the right.
    var beach: Path {
        var path = Path()
        path.move(to: point(0, 0.60))
        path.addCurve(to: point(1, 0.80), control1: point(0.35, 0.60), control2: point(0.70, 0.74))
        path.addLine(to: point(1, 1))
        path.addLine(to: point(0, 1))
        path.closeSubpath()
        return path
    }

    var waterBody: Path {
        Path(CGRect(x: 0, y: size.height * Self.horizon, width: size.width, height: size.height * (waterline - Self.horizon)))
    }

    var wetBand: Path {
        Path(CGRect(x: 0, y: size.height * waterline, width: size.width, height: size.height * 0.035))
    }

    var foamLine: Path {
        var path = Path()
        let y = waterline
        path.move(to: point(0, y))
        stride(from: CGFloat(0), through: 1, by: 0.05).forEach { x in
            path.addLine(to: point(x, y + 0.004 * sin(x * 37)))
        }
        return path
    }

    /// Thin horizontal sea marks, denser and shorter toward the horizon.
    var seaMarks: [(Path, CGFloat)] {
        let marks: [(x: CGFloat, length: CGFloat)] = [
            (0.08, 0.10), (0.55, 0.06), (0.30, 0.14), (0.72, 0.09), (0.12, 0.18),
            (0.48, 0.12), (0.80, 0.15), (0.22, 0.20), (0.62, 0.16), (0.05, 0.22),
        ]
        return marks.enumerated().compactMap { index, mark in
            let t = CGFloat(index + 1) / CGFloat(marks.count + 1)
            let y = Self.horizon + 0.015 + pow(t, 1.5) * (waterline - Self.horizon - 0.03)
            guard y < waterline - 0.01 else { return nil }
            var path = Path()
            path.move(to: point(mark.x, y))
            path.addLine(to: point(min(mark.x + mark.length * (0.6 + t), 0.98), y))
            return (path, 0.5 + t)
        }
    }

    var farLand: Path {
        let h = Self.horizon
        switch region {
        case .pacificHeadlands:
            var path = polygon([(0.52, h), (0.58, h - 0.05), (0.66, h - 0.10), (0.78, h - 0.12), (0.90, h - 0.16), (1, h - 0.17), (1, h)])
            path.addPath(polygon([(0.40, h), (0.405, h - 0.055), (0.425, h - 0.06), (0.43, h)]))
            path.addPath(polygon([(0.46, h), (0.465, h - 0.03), (0.48, h - 0.032), (0.485, h)]))
            return path
        case .northAtlantic:
            var path = polygon([(0, h - 0.035), (0.12, h - 0.03), (0.30, h - 0.018), (0.46, h - 0.008), (0.52, h)] + [(0, h)])
            path.addPath(polygon([(0.105, h - 0.03), (0.108, h - 0.10), (0.116, h - 0.10), (0.119, h - 0.03)]))
            return path
        case .southAtlanticMarsh:
            let bumps: [(CGFloat, CGFloat)] = stride(from: CGFloat(0), through: 1, by: 0.04).map { x in
                (x, h - 0.022 - 0.008 * abs(sin(x * 23)))
            }
            return polygon([(0, h)] + bumps + [(1, h)])
        case .gulfShore:
            return polygon([(0, h), (0, h - 0.012), (0.4, h - 0.006), (0.6, h)])
        case .tropicalIsland:
            var path = polygon([(0.22, h), (0.36, h - 0.10), (0.46, h - 0.19), (0.50, h - 0.20), (0.56, h - 0.17), (0.70, h - 0.07), (0.82, h)])
            path.addPath(polygon([(0.62, h), (0.74, h - 0.06), (0.86, h - 0.08), (1, h - 0.05), (1, h)]))
            return path
        case .northernFjord:
            return polygon([
                (0, h), (0, h - 0.14), (0.10, h - 0.22), (0.18, h - 0.13), (0.28, h - 0.26), (0.40, h - 0.12),
                (0.52, h - 0.20), (0.62, h - 0.09), (0.74, h - 0.18), (0.86, h - 0.10), (1, h - 0.16), (1, h),
            ])
        }
    }

    /// Light caps on the fjord peaks.
    var snowCaps: Path {
        guard region == .northernFjord else { return Path() }
        let h = Self.horizon
        var path = polygon([(0.08, h - 0.20), (0.10, h - 0.22), (0.125, h - 0.195)])
        path.addPath(polygon([(0.25, h - 0.23), (0.28, h - 0.26), (0.315, h - 0.225)]))
        path.addPath(polygon([(0.50, h - 0.18), (0.52, h - 0.20), (0.545, h - 0.178)]))
        return path
    }

    /// Objects standing in the shallows; drawn before the water so a rising tide covers them.
    var shallows: Path {
        switch region {
        case .pacificHeadlands, .tropicalIsland:
            var path = Path()
            path.addEllipse(in: CGRect(origin: point(0.66, 0.74), size: CGSize(width: size.width * 0.09, height: size.height * 0.07)))
            path.addEllipse(in: CGRect(origin: point(0.75, 0.765), size: CGSize(width: size.width * 0.05, height: size.height * 0.045)))
            path.addEllipse(in: CGRect(origin: point(0.84, 0.79), size: CGSize(width: size.width * 0.07, height: size.height * 0.05)))
            return path
        case .gulfShore:
            var path = Path()
            for (index, x) in [CGFloat(0.58), 0.65, 0.72, 0.79, 0.86].enumerated() {
                let top = 0.62 + CGFloat(index) * 0.012
                path.addRect(CGRect(origin: point(x, top), size: CGSize(width: size.width * 0.008, height: size.height * (0.86 - top))))
            }
            return path
        case .northernFjord:
            var path = Path()
            path.addRoundedRect(in: CGRect(origin: point(0.60, 0.79), size: CGSize(width: size.width * 0.22, height: size.height * 0.018)), cornerSize: CGSize(width: 3, height: 3))
            return path
        case .northAtlantic, .southAtlanticMarsh:
            return Path()
        }
    }

    /// Dune or marsh grass on the high, dry part of the beach (always above water).
    var grass: Path {
        guard region == .northAtlantic || region == .southAtlanticMarsh else { return Path() }
        var path = Path()
        let blades: [(CGFloat, CGFloat, CGFloat)] = [
            (0.04, 0.09, -0.01), (0.07, 0.12, 0.012), (0.10, 0.08, -0.006), (0.13, 0.11, 0.01),
            (0.16, 0.07, -0.012), (0.19, 0.10, 0.006), (0.23, 0.06, 0.01), (0.27, 0.05, -0.008),
        ]
        for (x, height, lean) in blades {
            let base = 0.62 + x * 0.04 + 0.06
            path.move(to: point(x, base))
            path.addQuadCurve(to: point(x + lean, base - height), control: point(x + lean * 0.2, base - height * 0.6))
        }
        return path
    }

    // MARK: Rendering

    func paint(in context: inout GraphicsContext, palette: CoastArtPalette) {
        context.fill(skyRect, with: .linearGradient(
            Gradient(colors: [palette.skyTop, palette.skyHorizon]),
            startPoint: point(0.5, 0), endPoint: point(0.5, Self.horizon)
        ))
        let sun = Path(ellipseIn: CGRect(origin: point(0.70, 0.30), size: CGSize(width: size.width * 0.11, height: size.width * 0.11)))
        context.fill(sun, with: .color(palette.sun.opacity(0.55)))
        context.fill(farLand, with: .color(palette.farLand))
        context.fill(snowCaps, with: .color(palette.skyHorizon.opacity(0.9)))
        context.fill(seaRect, with: .linearGradient(
            Gradient(colors: [palette.seaFar, palette.seaNear]),
            startPoint: point(0.5, Self.horizon), endPoint: point(0.5, 1)
        ))
        context.fill(beach, with: .color(palette.sand))
        context.fill(shallows, with: .color(palette.nearLand))
        // Water over the submerged part of the beach and shallows.
        var water = context
        water.clip(to: waterBody)
        water.fill(beach, with: .color(palette.seaNear.opacity(0.92)))
        water.fill(shallows, with: .color(palette.seaNear.opacity(0.85)))
        // Recently exposed sand is darker.
        var wet = context
        wet.clip(to: beach)
        wet.fill(wetBand, with: .color(palette.wetSand.opacity(0.75)))
        context.stroke(foamLine, with: .color(palette.foam.opacity(0.85)), lineWidth: max(1, size.width / 260))
        for (mark, weight) in seaMarks {
            context.stroke(mark, with: .color(palette.foam.opacity(0.35)), lineWidth: weight * max(0.6, size.width / 400))
        }
        context.stroke(grass, with: .color(palette.detail.opacity(0.7)), lineWidth: max(0.8, size.width / 320))
    }

    func outline(in context: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.color(.primary)
        let thin = max(0.8, size.width / 260)
        var horizonLine = Path()
        horizonLine.move(to: point(0, Self.horizon))
        horizonLine.addLine(to: point(1, Self.horizon))
        context.stroke(horizonLine, with: ink, lineWidth: thin)
        context.stroke(farLand, with: ink, lineWidth: thin)
        context.stroke(beach, with: ink, lineWidth: thin)
        context.stroke(foamLine, with: ink, lineWidth: thin * 1.6)
        for (mark, _) in seaMarks.prefix(5) {
            context.stroke(mark, with: .color(.primary.opacity(0.6)), lineWidth: thin * 0.8)
        }
        context.stroke(grass, with: ink, lineWidth: thin)
    }
}

#Preview("Regions") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(CoastRegion.allCases, id: \.self) { region in
                CoastArtView(region: region, waterLevel: 0.3).aspectRatio(4 / 3, contentMode: .fit)
            }
        }
        .padding()
    }
}
