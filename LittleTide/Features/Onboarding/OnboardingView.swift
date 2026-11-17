import SwiftUI
import TideKit
import TideUI

/// First launch: one painted coast, one glass card, one action.
struct OnboardingView: View {
    let onChooseCoast: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        CoastArtView(region: .southernCalifornia, waterLevel: 0.4, horizon: 0.42)
                            .frame(width: proxy.size.width, height: max(proxy.size.height * 0.72, 520))
                        HStack(spacing: 10) {
                            TideMark().frame(width: 24, height: 24)
                            Text("Little Tide").typeStyle(.brand).foregroundStyle(Palette.ink)
                        }
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .padding(.horizontal, 24)
                        .padding(.top, proxy.safeAreaInsets.top + 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text("Original illustration")
                            .typeStyle(.metadata)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .glassSurface(Capsule(), tint: Palette.paper.opacity(0.5))
                            .padding(16)
                            .padding(.bottom, 150)
                    }

                    card.padding(.top, -150)
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Palette.paper.ignoresSafeArea())
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A little window into your coast.")
                .typeStyle(.heroLocation)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Predicted high and low tides for NOAA stations across the United States, on your Home Screen and in a timeline you can explore with a finger.")
                .typeStyle(.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onChooseCoast) {
                Text("Choose your coast")
                    .typeStyle(.bodyEmphasis)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.ink)
            .foregroundStyle(Palette.paper)
            .padding(.top, 6)
            .accessibilityIdentifier("chooseCoast")
            Text("No account or location needed.")
                .typeStyle(.metadata)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .glassSurface(RoundedRectangle(cornerRadius: 32, style: .continuous), tint: Palette.paper.opacity(0.6))
        .padding(.horizontal, 14)
    }
}

#Preview { OnboardingView {} }
