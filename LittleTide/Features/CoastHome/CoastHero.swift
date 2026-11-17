import SwiftUI
import TideKit
import TideUI

/// Actions available from the hero's floating glass controls.
struct HeroActions {
    let chooseCoast: () -> Void
    let openSettings: () -> Void
    let openStationDetails: () -> Void
}

/// The first screen: the painted coast fills the display; the place and the tide right now
/// sit low over the water, as in a field guide plate.
struct CoastHero<Card: View>: View {
    let station: TideStation
    /// Normalised water level for the illustration (0 lowest … 1 highest in view).
    let level: Double
    let layout: HomeLayout
    let actions: HeroActions
    @ViewBuilder let card: Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panels: [GlassPanel] = []

    private var paintedScene: PaintedScene? { PaintedScene(region: CoastRegion(station: station)) }

    /// Legibility scrims, rendered inside the scene so the glass refracts them.
    private var scrim: SceneScrim {
        SceneScrim(topEnd: layout.topInset + 150, bottomStart: layout.height * 0.42, topAlpha: 0.88, bottomAlpha: 0.95)
    }

    var body: some View {
        // At least one screen tall; taller when large accessibility text needs the room, so the
        // tide card is never squeezed into truncation.
        content
            .frame(width: layout.width)
            .frame(minHeight: layout.height, alignment: .bottom)
            .overlay(alignment: .top) {
                header
                    .padding(.top, layout.topInset + 6)
                    .padding(.horizontal, 20)
            }
            .background {
                ZStack {
                    art
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: level)
                    if paintedScene == nil { fallbackScrims }
                }
                .clipped()
            }
            .glassStage("heroGlass") { panels = $0 }
    }

    /// Place, card and scroll hint, bottom-aligned; the header floats above them.
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
            card
                .padding(.top, 16)
            scrollHint
                .padding(.top, 18)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 20)
        // Room for the floating header (44 pt controls) plus breathing space.
        .padding(.top, layout.topInset + 6 + 44 + 24)
    }

    private var fallbackScrims: some View {
        // Scrims keep white type legible over any part of the painting.
        VStack(spacing: 0) {
                LinearGradient(stops: [.init(color: Palette.oceanDeep.opacity(0.88), location: 0),
                                       .init(color: Palette.oceanDeep.opacity(0.6), location: 0.6),
                                       .init(color: Palette.oceanDeep.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: layout.topInset + 150)
                Spacer()
                LinearGradient(stops: [.init(color: Palette.oceanDeep.opacity(0), location: 0),
                                       .init(color: Palette.oceanDeep.opacity(0.62), location: 0.35),
                                       .init(color: Palette.oceanDeep.opacity(0.88), location: 0.65),
                                       .init(color: Palette.oceanDeep.opacity(0.95), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: layout.height * 0.55)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var art: some View {
        if let scene = paintedScene {
            PaintedCoastView(scene: scene, level: level, scrim: scrim, panels: panels, isAnimating: layout.isHeroVisible)
        } else {
            // Regions without a painted scene yet keep the earlier illustration.
            CoastArtView(region: CoastRegion(station: station), waterLevel: level, horizon: 0.45)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TideMark().frame(width: 22, height: 22)
                .colorMultiply(.white)
            Text("Little Tide")
                .typeStyle(.brand)
                .foregroundStyle(Palette.onArt)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: actions.chooseCoast) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Change coast")
            .accessibilityIdentifier("changeCoast")
            Button(action: actions.openSettings) {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settings")
        }
        .foregroundStyle(Palette.onArt)
        .modifier(TextHalo())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.headline.region)
                .typeStyle(.regionLabel)
                .foregroundStyle(Palette.onArt)
                .lineLimit(2)
            Button(action: actions.openStationDetails) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(station.headline.place)
                        .typeStyle(.heroLocation)
                        .foregroundStyle(Palette.onArt)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Palette.onArtSoft)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(station.headline.place), \(station.headline.region)")
            .accessibilityHint("Shows station \(station.id) details and data source.")
            .accessibilityIdentifier("placeTitle")
        }
        .modifier(TextHalo())
    }

    private var scrollHint: some View {
        HStack(spacing: 6) {
            Spacer()
            Text("The tide today")
            Image(systemName: "chevron.down")
            Spacer()
        }
        .typeStyle(.label)
        .foregroundStyle(Palette.onArtSoft)
        .accessibilityHidden(true)
    }
}

/// A tight deep-teal halo plus a soft wider one: white type stays legible over bright
/// surf or pale sand without hiding the painting behind a plate.
struct TextHalo: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Palette.oceanDeep.opacity(0.95), radius: 2.5)
            .shadow(color: Palette.oceanDeep.opacity(0.8), radius: 10)
            .shadow(color: Palette.oceanDeep.opacity(0.5), radius: 24)
    }
}

/// Teal-tinted glass for content on painted water: genuinely translucent, white type.
struct OceanGlass: ViewModifier {
    var cornerRadius: CGFloat = 28

    func body(content: Content) -> some View {
        content.liquidGlass(cornerRadius: cornerRadius, kind: .card)
    }
}

struct OceanGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        LiquidGlassButtonStyle().makeBody(configuration: configuration)
    }
}

extension View {
    func oceanGlass(cornerRadius: CGFloat = 28) -> some View { modifier(OceanGlass(cornerRadius: cornerRadius)) }
}

/// The tide right now, as a compact glass card.
struct TideCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .oceanGlass(cornerRadius: 30)
    }
}

/// Soft frosted band behind the status bar, so scrolled content never collides with it.
struct StatusBarScrim: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(.regularMaterial)
                Palette.oceanDeep.opacity(0.9)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: proxy.safeAreaInsets.top + 30)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
