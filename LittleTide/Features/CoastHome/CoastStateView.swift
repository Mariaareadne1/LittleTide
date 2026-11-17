import SwiftUI
import TideKit
import TideUI

/// Loading, failure and expired states: the same coast and glass card, never with
/// invented tide values.
struct CoastStateView: View {
    enum Kind {
        case loading
        case failed(NOAAError)
        case expired(Date, TideFormat)
    }

    let station: TideStation
    let kind: Kind
    let layout: HomeLayout
    let actions: HeroActions
    var retry: (() -> Void)?
    var chooseAnother: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoastHero(station: station, level: 0.5, topInset: layout.topInset, width: layout.width, actions: actions)
                .saturation(isLoading ? 0.55 : 0.85)
            TideCard { message }
                .padding(.top, -150)
        }
    }

    @ViewBuilder
    private var message: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch kind {
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Retrieving predictions from NOAA…")
                        .typeStyle(.body).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("loadingState")
            case let .failed(error):
                Text("Predictions unavailable")
                    .typeStyle(.eventTitle).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(error.userMessage)
                    .typeStyle(.body).foregroundStyle(Palette.inkSoft)
                    .accessibilityIdentifier("errorMessage")
            case let .expired(lastUpdated, format):
                Text("Forecast unavailable")
                    .typeStyle(.eventTitle).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("The saved predictions (retrieved \(format.day(lastUpdated))) no longer cover the current time. Connect to the internet to get new predictions from NOAA.")
                    .typeStyle(.body).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("expiredMessage")
            }
            if !isLoading {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { buttons }
                    VStack(alignment: .leading, spacing: 10) { buttons }
                }
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if let retry {
            Button(action: retry) {
                Text("Try again").typeStyle(.bodyEmphasis).padding(.horizontal, 18).frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.ink)
            .accessibilityIdentifier("retryButton")
        }
        if let chooseAnother {
            Button(action: chooseAnother) {
                Text("Choose another coast").typeStyle(.bodyEmphasis).padding(.horizontal, 18).frame(minHeight: 44)
            }
            .buttonStyle(GlassButtonStyle())
            .foregroundStyle(Palette.ink)
        }
    }

    private var isLoading: Bool {
        if case .loading = kind { return true }
        return false
    }
}
