import SwiftUI
import TideKit

/// How a widget is being rendered. `.fullColor` paints; anything else (tinted, clear,
/// vibrant) uses line art and system colours so it never becomes a blank shape.
public enum CoastCardRendering: Sendable {
    case fullColor
    case monochrome
}

private struct CardColors {
    let rendering: CoastCardRendering
    var ink: Color { rendering == .fullColor ? Palette.ink : .primary }
    var soft: Color { rendering == .fullColor ? Palette.inkSoft : .secondary }
    var accent: Color { rendering == .fullColor ? Palette.seaGlassDeep : .primary }
    var marker: Color { rendering == .fullColor ? Palette.rust : .primary }
}

/// Small widget: one coast scene, one clear fact.
public struct SmallCoastCard: View {
    let content: CoastWidgetContent
    let rendering: CoastCardRendering

    public init(content: CoastWidgetContent, rendering: CoastCardRendering) {
        self.content = content
        self.rendering = rendering
    }

    public var body: some View {
        let colors = CardColors(rendering: rendering)
        switch content.state {
        case .unconfigured:
            UnconfiguredCard(rendering: rendering)
        case let .unavailable(station, _):
            VStack(alignment: .leading, spacing: 4) {
                CardArt(station: station, level: 0.5, rendering: rendering).frame(height: 52)
                Spacer(minLength: 0)
                Text(station.displayName.title).font(.system(.footnote, design: .serif)).foregroundStyle(colors.ink).lineLimit(2)
                Text("Open Little Tide to refresh predictions").font(.caption2).foregroundStyle(colors.soft).lineLimit(3)
            }
            .accessibilityElement(children: .combine)
        case let .ready(ready):
            VStack(alignment: .leading, spacing: 0) {
                CardArt(station: ready.station, level: level(ready), rendering: rendering)
                    .frame(height: 50)
                    .clipShape(.rect(cornerRadius: 3))
                Text(ready.station.displayName.title)
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)
                Spacer(minLength: 2)
                Text(ready.nextKindWord.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(colors.soft)
                Text(ready.nextTime)
                    .font(.system(size: 24, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentableIfAvailable()
                FactLine(ready: ready, colors: colors)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready.accessibilityLabel)
        }
    }

    private func level(_ ready: CoastWidgetContent.Ready) -> Double {
        ready.waterLevel ?? 0.5
    }
}

/// Medium widget: a horizontal postcard with the tide's rhythm over the next day.
public struct MediumCoastCard: View {
    let content: CoastWidgetContent
    let rendering: CoastCardRendering

    public init(content: CoastWidgetContent, rendering: CoastCardRendering) {
        self.content = content
        self.rendering = rendering
    }

    public var body: some View {
        let colors = CardColors(rendering: rendering)
        switch content.state {
        case .unconfigured:
            UnconfiguredCard(rendering: rendering)
        case let .unavailable(station, _):
            HStack(spacing: 14) {
                CardArt(station: station, level: 0.5, rendering: rendering)
                    .frame(width: 110).clipShape(.rect(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 6) {
                    Text(station.displayName.title).font(.system(.headline, design: .serif)).foregroundStyle(colors.ink).lineLimit(2)
                    Text("Forecast unavailable").font(.subheadline.weight(.semibold)).foregroundStyle(colors.ink)
                    Text("Open Little Tide to get new predictions from NOAA.").font(.caption).foregroundStyle(colors.soft)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        case let .ready(ready):
            HStack(spacing: 14) {
                CardArt(station: ready.station, level: ready.waterLevel ?? 0.5, rendering: rendering)
                    .frame(width: 96)
                    .clipShape(.rect(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ready.station.displayName.title)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(colors.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if ready.trend != .unknown {
                            Image(systemName: ready.trend == .rising ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(colors.accent)
                        }
                    }
                    Text(ready.headline)
                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 2)
                        .widgetAccentableIfAvailable()
                    FactLine(ready: ready, colors: colors)
                    Spacer(minLength: 4)
                    RhythmStrip(rhythm: ready.rhythm, rendering: rendering)
                        .frame(height: 38)
                    HStack {
                        Text(ready.rhythm.startLabel)
                        Spacer()
                        Text("NOAA \(ready.station.id)")
                        Spacer()
                        Text(ready.rhythm.endLabel)
                    }
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(colors.soft)
                    .lineLimit(1)
                    .padding(.top, 2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready.accessibilityLabel)
        }
    }
}

private struct FactLine: View {
    let ready: CoastWidgetContent.Ready
    let colors: CardColors

    var body: some View {
        let trend: String? = switch ready.trend {
        case .rising: "Rising"
        case .falling: "Falling"
        case .unknown: nil
        }
        let parts = [ready.nextHeight] + [trend, ready.agingNote].compactMap { $0 }
        Text(parts.joined(separator: " · "))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(colors.soft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct CardArt: View {
    let station: TideStation
    let level: Double
    let rendering: CoastCardRendering

    var body: some View {
        CoastArtView(region: CoastRegion(station: station), waterLevel: level, style: rendering == .fullColor ? .painted : .line)
            .opacity(rendering == .fullColor ? 1 : 0.55)
            .accessibilityHidden(true)
    }
}

private struct UnconfiguredCard: View {
    let rendering: CoastCardRendering

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TideMark().frame(width: 26, height: 26)
            Spacer(minLength: 0)
            Text("Little Tide").font(.system(.subheadline, design: .serif)).foregroundStyle(CardColors(rendering: rendering).ink)
            Text("Open the app to choose your coast.").font(.caption2).foregroundStyle(CardColors(rendering: rendering).soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A day of tide at a glance: the curve when NOAA publishes one, otherwise event marks.
struct RhythmStrip: View {
    let rhythm: CoastWidgetContent.Rhythm
    let rendering: CoastCardRendering

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: 0, y: 3, width: size.width, height: size.height - 6)
            let geometry = TideChartGeometry(window: rhythm.window, dataRange: rhythm.range, rect: rect, padding: 0.15)
            let line = rendering == .fullColor ? Palette.seaGlassDeep : Color.primary
            var clipped = context
            clipped.clip(to: Path(rect.insetBy(dx: 0, dy: -3)))
            if rhythm.samples.isEmpty {
                for event in rhythm.events {
                    let p = geometry.point(event)
                    var stem = Path()
                    stem.move(to: CGPoint(x: p.x, y: rect.maxY))
                    stem.addLine(to: p)
                    clipped.stroke(stem, with: .color(line.opacity(0.7)), lineWidth: 1.5)
                }
            } else {
                if rendering == .fullColor {
                    clipped.fill(Path(geometry.areaPath(samples: rhythm.samples)), with: .color(Palette.seaGlass.opacity(0.22)))
                }
                clipped.stroke(Path(geometry.curvePath(samples: rhythm.samples)), with: .color(line), lineWidth: 1.25)
            }
            for event in rhythm.events {
                let p = geometry.point(event)
                clipped.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(line))
            }
            let x = geometry.x(for: rhythm.now)
            var marker = Path()
            marker.move(to: CGPoint(x: x, y: rect.minY - 2))
            marker.addLine(to: CGPoint(x: x, y: rect.maxY + 2))
            context.stroke(marker, with: .color(rendering == .fullColor ? Palette.rust : .primary), lineWidth: 1.5)
            var base = Path()
            base.move(to: CGPoint(x: rect.minX, y: rect.maxY + 2))
            base.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + 2))
            context.stroke(base, with: .color(rendering == .fullColor ? Palette.sand : Color.secondary), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// `widgetAccentable` without importing WidgetKit into shared UI.
    @ViewBuilder
    func widgetAccentableIfAvailable() -> some View {
        #if canImport(WidgetKit) && os(iOS)
        self.modifier(AccentableModifier())
        #else
        self
        #endif
    }
}

#if canImport(WidgetKit) && os(iOS)
import WidgetKit

private struct AccentableModifier: ViewModifier {
    func body(content: Content) -> some View { content.widgetAccentable() }
}
#endif
