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
                        PaintedCoastView(scene: .eastCoast, level: 0.45)
                            .frame(width: proxy.size.width, height: max(proxy.size.height * 0.78, 560))
                            .overlay {
                                LinearGradient(stops: [.init(color: Palette.oceanDeep.opacity(0.7), location: 0),
                                                       .init(color: Palette.oceanDeep.opacity(0), location: 0.22),
                                                       .init(color: Palette.oceanDeep.opacity(0), location: 0.6),
                                                       .init(color: Palette.oceanDeep.opacity(0.85), location: 1)],
                                               startPoint: .top, endPoint: .bottom)
                            }
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
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text("Original illustration")
                            .typeStyle(.metadata)
                            .foregroundStyle(Palette.onArt)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .glassSurface(Capsule(), tint: Palette.oceanDeep.opacity(0.7))
                            .padding(16)
                            .padding(.bottom, 150)
                    }

                    card.padding(.top, -150)
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
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
        .glassSurface(RoundedRectangle(cornerRadius: 32, style: .continuous), tint: Palette.oceanDeep.opacity(0.82))
        .padding(.horizontal, 14)
    }
}

#Preview { OnboardingView {} }
