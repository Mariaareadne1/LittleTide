import SwiftUI
import TideKit
import TideUI

/// First launch: one painted coast, one glass card, one action.
struct OnboardingView: View {
    let onChooseCoast: () -> Void
    @State private var panels: [GlassPanel] = []

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        TideMark().frame(width: 24, height: 24)
                        Text("Little Tide").typeStyle(.brand).foregroundStyle(Palette.onArt)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .modifier(TextHalo())
                    .padding(.horizontal, 24)
                    .padding(.top, proxy.safeAreaInsets.top + 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: max(proxy.size.height * 0.42, 260))

                    HStack {
                        Spacer()
                        Text("Original illustration")
                            .typeStyle(.metadata)
                            .foregroundStyle(Palette.onArt)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .liquidGlass(cornerRadius: 999, kind: .button)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    card
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16) + 16)
                }
                .frame(minHeight: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom, alignment: .top)
                // The painting spans the whole page, so every glass panel has art to refract.
                .background {
                    GeometryReader { inner in
                        PaintedCoastView(scene: .eastCoast, level: 0.45,
                                         scrim: SceneScrim(topEnd: proxy.safeAreaInsets.top + 140, bottomStart: inner.size.height * 0.48,
                                                           topAlpha: 0.85, bottomAlpha: 0.9),
                                         panels: panels)
                    }
                }
                .glassStage("onboardingGlass") { panels = $0 }
            }
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .background(Palette.oceanDeep.ignoresSafeArea())
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A little window into your coast.")
                .typeStyle(.heroLocation)
                .foregroundStyle(Palette.onArt)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Predicted high and low tides for NOAA stations across the United States, on your Home Screen and in a timeline you can explore with a finger.")
                .typeStyle(.body)
                .foregroundStyle(Palette.onArtSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onChooseCoast) {
                Text("Choose your coast")
                    .typeStyle(.bodyEmphasis)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.white)
            .foregroundStyle(Palette.oceanDeep)
            .padding(.top, 6)
            .accessibilityIdentifier("chooseCoast")
            Text("No account or location needed.")
                .typeStyle(.metadata)
                .foregroundStyle(Palette.onArtSoft)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .liquidGlass(cornerRadius: 32, kind: .card)
        .padding(.horizontal, 14)
    }
}

#Preview { OnboardingView {} }
