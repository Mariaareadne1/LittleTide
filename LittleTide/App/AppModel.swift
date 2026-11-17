import Foundation
import Observation
import TideKit
import WidgetKit

/// App-wide state: the chosen coast, its forecast and user preferences.
@Observable
@MainActor
final class AppModel {
    private(set) var catalog: StationCatalog?
    private(set) var station: TideStation?
    private(set) var forecastState: ForecastState = .idle
    private(set) var isRefreshing = false
    /// Increments whenever the coast changes, so views can reset their selection.
    private(set) var stationGeneration = 0

    var unit: HeightUnit { didSet { settings.setUnit(unit); reloadWidgets() } }
    var treatment: VisualTreatment { didSet { settings.setVisualTreatment(treatment); reloadWidgets() } }
    var isHapticsEnabled: Bool { didSet { UserDefaults.standard.set(isHapticsEnabled, forKey: Self.hapticsKey) } }

    let clock: AppClock
    private let repository: TideRepository
    private let settings: SharedSettings
    private let widgetReloader: @MainActor () -> Void
    private var loadTask: Task<Void, Never>?
    private var requestToken = 0

    static let hapticsKey = "hapticsEnabled"

    init(
        repository: TideRepository,
        settings: SharedSettings,
        clock: AppClock,
        catalog: StationCatalog? = nil,
        widgetReloader: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.coast) }
    ) {
        self.repository = repository
        self.settings = settings
        self.clock = clock
        self.catalog = catalog
        self.widgetReloader = widgetReloader
        station = settings.selectedStation
        unit = settings.unit
        treatment = settings.visualTreatment
        isHapticsEnabled = UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool ?? true
    }

    /// Asks WidgetKit to re-render from the shared cache, e.g. after an app update
    /// changed the widget design. Cheap: no network unless the refresh policy says so.
    func reloadWidgetsOnLaunch() {
        reloadWidgets()
    }

    func loadCatalogIfNeeded() async {
        guard catalog == nil else { return }
        catalog = await Task.detached(priority: .userInitiated) { try? StationCatalog.bundled() }.value
    }

    /// Chooses a coast. Clears the previous coast's data immediately so it can never
    /// appear under the new name.
    func select(_ newStation: TideStation) {
        guard newStation != station else { return }
        settings.setSelectedStation(newStation)
        station = newStation
        stationGeneration += 1
        forecastState = .idle
        reloadWidgets()
        refresh(manual: false)
    }

    /// Loads cached predictions immediately, then refreshes from NOAA if due.
    func refresh(manual: Bool) {
        guard let station else { return }
        loadTask?.cancel()
        requestToken += 1
        let token = requestToken
        isRefreshing = true
        loadTask = Task { [repository] in
            if forecastState.forecast?.stationID != station.id,
               let cached = await repository.cachedForecast(for: station.id) {
                guard isCurrent(token, station) else { return }
                forecastState = .ready(cached, refreshError: nil)
            }
            if forecastState.forecast == nil { forecastState = .loading }
            do {
                let result = try await repository.forecast(for: station, manual: manual)
                guard isCurrent(token, station) else { return }
                switch result.origin {
                case .network:
                    forecastState = .ready(result.forecast, refreshError: nil)
                    reloadWidgets()
                case .cache:
                    forecastState = .ready(result.forecast, refreshError: nil)
                case let .cacheAfterFailure(error):
                    forecastState = .ready(result.forecast, refreshError: error)
                }
            } catch {
                guard isCurrent(token, station) else { return }
                let noaaError = (error as? NOAAError) ?? .noConnection
                guard noaaError != .cancelled else { return }
                if let shown = forecastState.forecast, shown.stationID == station.id {
                    // Keep the dated copy; the view decides whether it is still usable
                    // (and shows "Forecast unavailable" when it is not).
                    forecastState = .ready(shown, refreshError: noaaError)
                } else {
                    forecastState = .failed(noaaError)
                }
            }
            if isCurrent(token, station) { isRefreshing = false }
        }
    }

    /// Opens a coast from a widget deep link. Unknown or removed stations are ignored.
    func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case let .station(id):
            if id == station?.id { return }
            if let match = catalog?.station(id: id) { select(match) }
        }
    }

    func clearCachedPredictions() async {
        try? await repository.clearCache()
        forecastState = .idle
        refresh(manual: false)
    }

    private func isCurrent(_ token: Int, _ requested: TideStation) -> Bool {
        token == requestToken && requested.id == station?.id && !Task.isCancelled
    }

    private func reloadWidgets() {
        widgetReloader()
    }
}

enum WidgetKind {
    static let coast = "LittleTideCoast" // must match CoastWidget.kind
}
