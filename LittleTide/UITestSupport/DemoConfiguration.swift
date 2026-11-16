#if DEBUG
import Foundation
import TideKit

/// DEBUG-only deterministic environment for UI tests and layout screenshots.
/// Serves real captured NOAA responses (Nov 15–18 2026) with a fixed clock.
///
///     -LTDemo <scenario> [-LTNow 2026-11-16T18:20:00Z] [-LTStation <id>]
///
/// Excluded from Release builds (see `EXCLUDED_SOURCE_FILE_NAMES` in project.yml).
struct DemoConfiguration {
    enum Scenario: String {
        /// First launch, no coast chosen.
        case onboarding
        /// A coast with a 15-minute curve.
        case curve
        /// A subordinate station: high/low events only.
        case highLow
        /// Offline with an older cached forecast.
        case offline
        /// Offline with nothing cached.
        case failure
        /// Cached forecast that no longer reaches "now".
        case expired
        /// NOAA responds slowly, to show loading.
        case slow
    }

    let scenario: Scenario
    let now: Date
    let stationID: String?

    init?(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        guard let raw = value(after: "-LTDemo"), let scenario = Scenario(rawValue: raw) else { return nil }
        self.scenario = scenario
        now = value(after: "-LTNow").flatMap { ISO8601DateFormatter().date(from: $0) }
            ?? ISO8601DateFormatter().date(from: "2026-11-16T18:20:00Z")!
        stationID = value(after: "-LTStation")
    }

    @MainActor
    func makeModel() -> AppModel {
        let defaults = UserDefaults(suiteName: "LittleTideDemo")!
        defaults.removePersistentDomain(forName: "LittleTideDemo")
        let settings = SharedSettings(defaults: defaults)
        let catalog = try? StationCatalog.bundled()
        let cache = DemoCache()
        let clockNow = now

        let defaultID = scenario == .highLow ? "9410738" : "9410840"
        if scenario != .onboarding, let station = catalog?.station(id: stationID ?? defaultID) {
            settings.setSelectedStation(station)
        }
        switch scenario {
        case .offline:
            if let forecast = Self.fixtureForecast(stationID: stationID ?? defaultID, fetchedAt: now.addingTimeInterval(-20 * 3600)) {
                try? cache.save(forecast)
            }
        case .expired:
            if let forecast = Self.fixtureForecast(stationID: stationID ?? defaultID, fetchedAt: now.addingTimeInterval(-9 * 24 * 3600)) {
                try? cache.save(forecast)
            }
        default: break
        }

        let transport: HTTPTransport
        switch scenario {
        case .offline, .failure, .expired: transport = DemoTransport(mode: .offline)
        case .slow: transport = DemoTransport(mode: .slow)
        default: transport = DemoTransport(mode: .fixtures)
        }
        let repository = TideRepository(
            client: NOAATideClient(transport: transport, retryDelays: []),
            cache: cache,
            now: { clockNow }
        )
        return AppModel(
            repository: repository, settings: settings, clock: .fixed(now),
            catalog: catalog, widgetReloader: {}
        )
    }

    static func fixtureForecast(stationID: String, fetchedAt: Date) -> TideForecast? {
        guard let hilo = DemoTransport.fixture(stationID == "9410738" ? "kingharbor_9410738_hilo" : "santamonica_9410840_hilo"),
              let events = try? NOAADecoder.events(from: hilo) else { return nil }
        let samples = stationID == "9410738" ? [] : (DemoTransport.fixture("santamonica_9410840_15min").flatMap { try? NOAADecoder.samples(from: $0) } ?? [])
        return TideForecast(
            stationID: stationID, datum: "MLLW", fetchedAt: fetchedAt,
            coverage: DateInterval(start: events.first!.date, end: events.last!.date),
            events: events, samples: samples,
            curve: samples.isEmpty ? .unavailable(reason: "NOAA publishes only high and low predictions for subordinate stations.") : .available(intervalMinutes: 15)
        )
    }
}

struct DemoTransport: HTTPTransport {
    enum Mode { case fixtures, offline, slow }
    let mode: Mode

    static func fixture(_ name: String) -> Data? {
        Bundle.main.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        switch mode {
        case .offline: throw URLError(.notConnectedToInternet)
        case .slow: try await Task.sleep(for: .seconds(30))
        case .fixtures: break
        }
        let url = request.url!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let station = items.first { $0.name == "station" }?.value ?? ""
        let interval = items.first { $0.name == "interval" }?.value ?? ""
        let name: String
        switch (station, interval) {
        case ("9410738", "hilo"): name = "kingharbor_9410738_hilo"
        case (_, "hilo"): name = "santamonica_9410840_hilo"
        default: name = "santamonica_9410840_15min"
        }
        let body = Self.fixture(name) ?? Data()
        return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

final class DemoCache: ForecastCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: TideForecast] = [:]
    func load(stationID: String) -> TideForecast? { lock.withLock { storage[stationID] } }
    func save(_ forecast: TideForecast) throws { lock.withLock { storage[forecast.stationID] = forecast } }
    func removeAll() throws { lock.withLock { storage.removeAll() } }
}
#endif
