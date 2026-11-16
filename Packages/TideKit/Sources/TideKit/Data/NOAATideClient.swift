import Foundation

/// Fetches tide predictions from NOAA CO-OPS. Independent of UI and storage.
public struct NOAATideClient: Sendable {
    /// Hours of history requested before "now", so the previous event is known.
    public static let lookbackHours = 36
    /// Hours requested after "now"; enough for a week of widget timelines.
    public static let lookaheadHours = 7 * 24
    public static let curveIntervalMinutes = 15

    private let transport: HTTPTransport
    private let sleeper: Sleeper
    private let retryDelays: [Double]
    private let timeout: TimeInterval

    public init(
        transport: HTTPTransport = URLSessionTransport(),
        sleeper: Sleeper = TaskSleeper(),
        retryDelays: [Double] = [2, 6],
        timeout: TimeInterval = 20
    ) {
        self.transport = transport
        self.sleeper = sleeper
        self.retryDelays = retryDelays
        self.timeout = timeout
    }

    /// Fetches high/low events (required) and, for reference stations, a 15-minute
    /// curve (optional). A missing curve degrades to an honest high/low-only forecast.
    public func fetchForecast(for station: TideStation, now: Date) async throws(NOAAError) -> TideForecast {
        let begin = Self.requestStart(for: now)
        let range = Self.lookbackHours + Self.lookaheadHours
        let hiloRequest = NOAARequest(stationID: station.id, begin: begin, rangeHours: range, interval: .highLow)
        let events = try NOAADecoder.events(from: try await fetch(hiloRequest))

        let samples: [TideSample]
        let curve: TideForecast.CurveAvailability
        if station.kind == .reference {
            let curveRequest = NOAARequest(
                stationID: station.id, begin: begin, rangeHours: range,
                interval: .minutes(Self.curveIntervalMinutes)
            )
            do {
                samples = try NOAADecoder.samples(from: try await fetch(curveRequest))
                curve = .available(intervalMinutes: Self.curveIntervalMinutes)
            } catch .cancelled {
                throw .cancelled
            } catch {
                samples = []
                curve = .unavailable(reason: Self.curveUnavailableReason(for: error))
            }
        } else {
            samples = []
            curve = .unavailable(reason: "NOAA publishes only high and low predictions for subordinate stations.")
        }

        return TideForecast(
            stationID: station.id,
            datum: hiloRequest.datum,
            fetchedAt: now,
            coverage: hiloRequest.coverage,
            events: events,
            samples: samples,
            curve: curve
        )
    }

    static func curveUnavailableReason(for error: NOAAError) -> String {
        switch error {
        case .rejected, .noPredictions:
            return "NOAA does not provide interval predictions for this station."
        default:
            return "Interval predictions could not be retrieved this time."
        }
    }

    /// Aligned to the hour so repeated refreshes produce identical, cache-friendly URLs.
    static func requestStart(for now: Date) -> Date {
        let hour = floor(now.timeIntervalSince1970 / 3600) * 3600
        return Date(timeIntervalSince1970: hour - TimeInterval(lookbackHours) * 3600)
    }

    // MARK: Transport

    func fetch(_ request: NOAARequest) async throws(NOAAError) -> Data {
        var attempt = 0
        while true {
            do {
                return try await fetchOnce(request)
            } catch where error.isTransient && attempt < retryDelays.count {
                do {
                    try await sleeper.sleep(seconds: retryDelays[attempt])
                } catch {
                    throw .cancelled
                }
                attempt += 1
            }
        }
    }

    private func fetchOnce(_ request: NOAARequest) async throws(NOAAError) -> Data {
        if Task.isCancelled { throw .cancelled }
        var urlRequest = URLRequest(url: request.url, timeoutInterval: timeout)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: urlRequest)
        } catch {
            throw Self.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw .malformedResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 403, 429: throw .throttled
        case 400..<500:
            // NOAA reports invalid stations/dates as 400 with a JSON `error` message,
            // which the decoder surfaces as `.rejected`.
            _ = try NOAADecoder.events(from: data)
            throw .server(status: http.statusCode)
        default: throw .server(status: http.statusCode)
        }
    }

    static func map(_ error: Error) -> NOAAError {
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .noConnection }
        switch urlError.code {
        case .cancelled: return .cancelled
        case .timedOut: return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dataNotAllowed, .internationalRoamingOff, .dnsLookupFailed:
            return .noConnection
        default:
            return .server(status: urlError.errorCode)
        }
    }
}
