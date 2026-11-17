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

    var body: some View {
        ZStack(alignment: .bottom) {
            art
                .frame(width: layout.width, height: layout.height)
                .clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: level)
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

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, layout.topInset + 6)
                Spacer(minLength: 24)
                identity
                card
                    .padding(.top, 16)
                scrollHint
                    .padding(.top, 18)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)
        }
        .frame(width: layout.width, height: layout.height)
    }

    @ViewBuilder
    private var art: some View {
        if let scene = PaintedScene(region: CoastRegion(station: station)) {
            PaintedCoastView(scene: scene, level: level)
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
            .buttonStyle(OceanGlassButtonStyle())
            .accessibilityLabel("Change coast")
            .accessibilityIdentifier("changeCoast")
            Button(action: actions.openSettings) {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(OceanGlassButtonStyle())
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
                .foregroundStyle(Palette.onArtSoft)
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
        content.glassSurface(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: Palette.oceanDeep.opacity(0.82))
    }
}

struct OceanGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassSurface(Capsule(), interactive: true, tint: Palette.oceanDeep.opacity(0.7))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
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
                Rectangle().fill(.ultraThinMaterial)
                Palette.oceanDeep.opacity(0.7)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: proxy.safeAreaInsets.top + 18)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
