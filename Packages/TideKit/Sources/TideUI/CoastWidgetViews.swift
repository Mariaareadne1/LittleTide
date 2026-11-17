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

/// The painted scene behind a widget (full colour only). Shared by the widget's
/// `containerBackground` and the in-app preview so both look identical.
public struct CoastWidgetBackground: View {
    public enum Family: Sendable { case small, medium }

    let content: CoastWidgetContent
    let family: Family

    public init(content: CoastWidgetContent, family: Family) {
        self.content = content
        self.family = family
    }

    public var body: some View {
        ZStack {
            Palette.paper
            if let station = content.station {
                CoastArtView(region: CoastRegion(station: station), waterLevel: content.waterLevel ?? 0.5,
                             horizon: family == .small ? 0.36 : 0.42)
                    .accessibilityHidden(true)
            }
            // A soft paper veil where the type sits, so it reads in one glance.
            switch family {
            case .small:
                LinearGradient(stops: [.init(color: Palette.paper.opacity(0), location: 0.34),
                                       .init(color: Palette.paper.opacity(0.9), location: 0.6),
                                       .init(color: Palette.paper.opacity(0.97), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            case .medium:
                LinearGradient(stops: [.init(color: Palette.paper.opacity(0.97), location: 0),
                                       .init(color: Palette.paper.opacity(0.9), location: 0.46),
                                       .init(color: Palette.paper.opacity(0), location: 0.72)],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
    }
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
            VStack(alignment: .leading, spacing: 3) {
                if rendering == .monochrome { LineArt(station: station, level: 0.5).frame(height: 54) }
                Spacer(minLength: 0)
                Text(station.displayName.title).typeStyle(.widgetPlace).foregroundStyle(colors.ink).lineLimit(2)
                Text("Open Little Tide to refresh predictions").typeStyle(.widgetSecondary).foregroundStyle(colors.soft).lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case let .ready(ready):
            VStack(alignment: .leading, spacing: 1) {
                if rendering == .monochrome { LineArt(station: ready.station, level: ready.waterLevel ?? 0.5).frame(height: 50) }
                Spacer(minLength: 0)
                EventKindLine(ready: ready, colors: colors)
                Text(ready.nextTime)
                    .typeStyle(.widgetHeroSmall)
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentableIfAvailable()
                Text([ready.station.displayName.title, ready.nextHeight].joined(separator: " · "))
                    .typeStyle(.widgetSecondary)
                    .foregroundStyle(colors.soft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let aging = ready.agingNote {
                    Text(aging).typeStyle(.widgetSecondary).foregroundStyle(colors.soft).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready.accessibilityLabel)
        }
    }
}

/// Medium widget: a wide painted scene with the next tide set in its quiet side.
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
                VStack(alignment: .leading, spacing: 5) {
                    Text(station.displayName.title).typeStyle(.widgetPlace).foregroundStyle(colors.ink).lineLimit(2)
                    Text("Forecast unavailable").typeStyle(.widgetHeroMedium).foregroundStyle(colors.ink).minimumScaleFactor(0.6).lineLimit(1)
                    Text("Open Little Tide to get new predictions from NOAA.").typeStyle(.widgetSecondary).foregroundStyle(colors.soft)
                }
                Spacer(minLength: 0)
                if rendering == .monochrome { LineArt(station: station, level: 0.5).frame(width: 110) }
            }
            .accessibilityElement(children: .combine)
        case let .ready(ready):
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ready.station.displayName.title)
                        .typeStyle(.widgetPlace)
                        .foregroundStyle(colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    EventKindLine(ready: ready, colors: colors)
                    Text(ready.nextTime)
                        .typeStyle(.widgetHeroMedium)
                        .foregroundStyle(colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .widgetAccentableIfAvailable()
                    Text(supportingLine(ready))
                        .typeStyle(.widgetSecondary)
                        .foregroundStyle(colors.soft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    RhythmStrip(rhythm: ready.rhythm, rendering: rendering)
                        .frame(height: 20)
                        .padding(.top, 6)
                }
                .frame(maxWidth: 176, alignment: .leading)
                Spacer(minLength: 0)
                if rendering == .monochrome {
                    LineArt(station: ready.station, level: ready.waterLevel ?? 0.5).frame(maxWidth: 120)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready.accessibilityLabel)
        }
    }

    private func supportingLine(_ ready: CoastWidgetContent.Ready) -> String {
        var parts = [ready.nextHeight]
        if let following = ready.followingSummary { parts.append(following) }
        if let aging = ready.agingNote { parts = [ready.nextHeight, aging] }
        return parts.joined(separator: " · ")
    }
}

/// "LOW TIDE ↘": the event kind with the direction, when defensible.
private struct EventKindLine: View {
    let ready: CoastWidgetContent.Ready
    let colors: CardColors

    var body: some View {
        HStack(spacing: 4) {
            Text("\(ready.nextKindWord) tide")
            switch ready.trend {
            case .rising: Image(systemName: "arrow.up.right")
            case .falling: Image(systemName: "arrow.down.right")
            case .unknown: EmptyView()
            }
        }
        .typeStyle(.widgetMicro)
        .foregroundStyle(colors.accent)
    }
}

private struct LineArt: View {
    let station: TideStation
    let level: Double

    var body: some View {
        CoastArtView(region: CoastRegion(station: station), waterLevel: level, style: .line)
            .opacity(0.55)
            .accessibilityHidden(true)
    }
}

private struct UnconfiguredCard: View {
    let rendering: CoastCardRendering

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TideMark().frame(width: 26, height: 26)
            Spacer(minLength: 0)
            Text("Little Tide").typeStyle(.widgetHeroMedium).foregroundStyle(CardColors(rendering: rendering).ink)
            Text("Open the app to choose your coast.").typeStyle(.widgetSecondary).foregroundStyle(CardColors(rendering: rendering).soft)
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
