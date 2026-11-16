import SwiftUI
import TideKit
import TideUI

/// Loading, failure and expired states: still composed like the coast, never with
/// invented tide values.
struct CoastStateView: View {
    enum Kind {
        case loading
        case failed(NOAAError)
        case expired(Date, TideFormat)
    }

    let station: TideStation
    let kind: Kind
    var retry: (() -> Void)?
    var chooseAnother: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoastArtView(region: CoastRegion(station: station), waterLevel: 0.5)
                .aspectRatio(3 / 2, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 2))
                .opacity(isLoading ? 0.55 : 0.8)
                .saturation(isLoading ? 0.4 : 0.8)
                .padding(.top, 8)

            Text(station.displayName.title)
                .font(Typography.placeTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.top, 20)
            Text("\(station.displayName.subtitle) · Station \(station.id)")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 10) {
                switch kind {
                case .loading:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Retrieving predictions from NOAA…")
                            .font(Typography.body).foregroundStyle(Palette.inkSoft)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("loadingState")
                case let .failed(error):
                    Text("Predictions unavailable")
                        .font(Typography.sectionTitle).foregroundStyle(Palette.ink)
                    Text(error.userMessage)
                        .font(Typography.body).foregroundStyle(Palette.inkSoft)
                        .accessibilityIdentifier("errorMessage")
                case let .expired(lastUpdated, format):
                    Text("Forecast unavailable")
                        .font(Typography.sectionTitle).foregroundStyle(Palette.ink)
                    Text("The saved predictions (retrieved \(format.day(lastUpdated))) no longer cover the current time. Connect to the internet to get new predictions from NOAA.")
                        .font(Typography.body).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("expiredMessage")
                }
                if !isLoading {
                    HStack(spacing: 12) {
                        if let retry {
                            Button("Try again", action: retry)
                                .buttonStyle(.borderedProminent).tint(Palette.ink)
                                .accessibilityIdentifier("retryButton")
                        }
                        if let chooseAnother {
                            Button("Choose another coast", action: chooseAnother)
                                .buttonStyle(.bordered).tint(Palette.ink)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.top, 24)
        }
    }

    private var isLoading: Bool {
        if case .loading = kind { return true }
        return false
    }
}
