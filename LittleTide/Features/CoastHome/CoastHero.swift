import SwiftUI
import TideKit
import TideUI

/// Actions available from the hero's floating glass controls.
struct HeroActions {
    let chooseCoast: () -> Void
    let openSettings: () -> Void
}

/// Layer A + B: the edge-to-edge painted coast with the station's identity set in its sky.
/// The horizon follows the title, so long names never land on the water.
struct CoastHero: View {
    let station: TideStation
    let level: Double
    let topInset: CGFloat
    let width: CGFloat
    let actions: HeroActions
    /// Extra painted space below the title for an overlapping card.
    var bottomRoom: CGFloat = 250

    @State private var titleBottom: CGFloat = 200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let maximumHorizon: CGFloat = 0.6

    /// Tall enough that the horizon always falls below the title.
    private var height: CGFloat { max(width * 1.22, titleBottom + bottomRoom, (titleBottom + 44) / Self.maximumHorizon) }
    private var horizon: CGFloat { min(max((titleBottom + 44) / height, 0.34), Self.maximumHorizon) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoastArtView(region: CoastRegion(station: station), waterLevel: level, horizon: horizon)
                .frame(width: width, height: height)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: level)
                .accessibilitySortPriority(-1)

            VStack(alignment: .leading, spacing: 0) {
                header
                identity.padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset + 4)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: TitleBottomKey.self, value: proxy.frame(in: .named("hero")).maxY)
                }
            )
        }
        .frame(width: width, height: height, alignment: .top)
        .overlay(alignment: .bottom) {
            // Let the painted sand settle into the paper below rather than ending on a line.
            LinearGradient(colors: [Palette.paper.opacity(0), Palette.paper], startPoint: .top, endPoint: .bottom)
                .frame(height: 70)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .clipped()
        .coordinateSpace(name: "hero")
        .onPreferenceChange(TitleBottomKey.self) { titleBottom = $0 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TideMark().frame(width: 22, height: 22)
            Text("Little Tide")
                .typeStyle(.brand)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: actions.chooseCoast) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel("Change coast")
            .accessibilityIdentifier("changeCoast")
            Button(action: actions.openSettings) {
                Image(systemName: "gearshape").font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settings")
        }
        .foregroundStyle(Palette.ink)
        // Chrome stays compact at accessibility sizes; content below scales fully.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.displayName.subtitle)
                .typeStyle(.regionLabel)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .glassSurface(Capsule(), tint: Palette.paper.opacity(0.5))
            Text(station.displayName.title)
                .typeStyle(.heroLocation)
                .foregroundStyle(Palette.ink)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        // A soft veil of sky keeps the type legible over any painted scene.
        .shadow(color: Palette.skyVeil.opacity(0.7), radius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.displayName.title), \(station.displayName.subtitle). Station \(station.id).")
    }
}

private struct TitleBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 200
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Layer C: the floating glass card with the tide right now.
struct TideCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: Palette.paper.opacity(0.55))
            .padding(.horizontal, 14)
    }
}

/// Soft frosted band behind the status bar, so scrolled content never collides with it.
struct StatusBarScrim: View {
    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: proxy.safeAreaInsets.top + 10)
                .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
