import SwiftUI
import TideKit
import TideUI

/// First launch: one quiet page, one action.
struct OnboardingView: View {
    let onChooseCoast: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CoastArtView(region: .pacificHeadlands, waterLevel: 0.35)
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 2))
                    .overlay(alignment: .bottomLeading) {
                        Text("Original illustration")
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Palette.paper.opacity(0.85), in: .rect(cornerRadius: 2))
                            .padding(10)
                    }
                    .padding(.top, 12)

                HStack(spacing: 8) {
                    TideMark().frame(width: 22, height: 22)
                    EditorialLabel("Little Tide")
                }
                .padding(.top, 28)

                Text("A little window into your coast.")
                    .font(Typography.placeTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)

                Text("Predicted high and low tides for NOAA stations across the United States, on your home screen and in a timeline you can explore with a finger.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                Button(action: onChooseCoast) {
                    Text("Choose your coast")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.ink)
                .foregroundStyle(Palette.paper)
                .buttonBorderShape(.roundedRectangle(radius: 4))
                .padding(.top, 28)
                .accessibilityIdentifier("chooseCoast")

                Text("No account or location needed.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .background(Palette.paper.ignoresSafeArea())
    }
}

#Preview { OnboardingView {} }
