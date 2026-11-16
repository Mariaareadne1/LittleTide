import Foundation
import TideKit

/// Explicit UI states for the selected coast's forecast.
enum ForecastState: Equatable {
    /// No request has started for the current station yet.
    case idle
    /// Fetching with nothing cached for this station.
    case loading
    /// Predictions to show. `refreshError` is set when the latest refresh failed and the
    /// forecast shown is an older cached copy.
    case ready(TideForecast, refreshError: NOAAError?)
    /// Nothing usable to show.
    case failed(NOAAError)

    var forecast: TideForecast? {
        if case let .ready(forecast, _) = self { return forecast }
        return nil
    }
}
