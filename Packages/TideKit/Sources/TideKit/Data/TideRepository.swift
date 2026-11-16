import Foundation

/// The single place the app and widget get forecasts from: cache first, NOAA when
/// needed, cached data (clearly dated) when NOAA is unreachable.
public actor TideRepository {
    public struct Result: Sendable {
        public enum Origin: Equatable, Sendable {
            case network
            case cache
            /// A refresh failed; this is the most recent cached forecast.
            case cacheAfterFailure(NOAAError)
        }

        public let forecast: TideForecast
        public let origin: Origin
    }

    /// Without a manual refresh, NOAA is not contacted more often than this.
    public static let minimumAutomaticRefreshInterval: TimeInterval = 3 * 60 * 60
    /// A cached forecast must reach at least this far ahead to skip a refresh.
    public static let minimumLookahead: TimeInterval = 3 * 24 * 60 * 60
    /// Even manual refreshes are spaced by this, to be respectful of NOAA.
    public static let minimumManualRefreshInterval: TimeInterval = 60

    private let client: NOAATideClient
    private let cache: ForecastCaching
    private let now: @Sendable () -> Date
    private var inFlight: [String: Task<TideForecast, Error>] = [:]

    public init(client: NOAATideClient, cache: ForecastCaching, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.cache = cache
        self.now = now
    }

    public func cachedForecast(for stationID: String) -> TideForecast? {
        cache.load(stationID: stationID)
    }

    public func needsRefresh(_ forecast: TideForecast?, manual: Bool) -> Bool {
        guard let forecast else { return true }
        let age = now().timeIntervalSince(forecast.fetchedAt)
        if manual { return age >= Self.minimumManualRefreshInterval }
        let reach = (forecast.lastUsefulInstant ?? forecast.coverage.end).timeIntervalSince(now())
        return age >= Self.minimumAutomaticRefreshInterval || reach < Self.minimumLookahead
    }

    public func forecast(for station: TideStation, manual: Bool = false) async throws -> Result {
        let cached = cache.load(stationID: station.id)
        if let cached, !needsRefresh(cached, manual: manual) {
            return Result(forecast: cached, origin: .cache)
        }
        do {
            let fresh = try await fetchDeduplicated(station)
            try? cache.save(fresh)
            return Result(forecast: fresh, origin: .network)
        } catch {
            let noaaError = (error as? NOAAError) ?? NOAATideClient.map(error)
            if noaaError == .cancelled { throw noaaError }
            if let cached, TideEngine.freshness(of: cached, at: now()).isUsable {
                return Result(forecast: cached, origin: .cacheAfterFailure(noaaError))
            }
            throw noaaError
        }
    }

    private func fetchDeduplicated(_ station: TideStation) async throws -> TideForecast {
        if let existing = inFlight[station.id] { return try await existing.value }
        let client = self.client
        let instant = now()
        let task = Task { () throws -> TideForecast in
            try await client.fetchForecast(for: station, now: instant)
        }
        inFlight[station.id] = task
        defer { inFlight[station.id] = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    public func clearCache() throws {
        try cache.removeAll()
    }
}
