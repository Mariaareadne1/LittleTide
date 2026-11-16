import Foundation
import Testing
@testable import TideKit

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

func utc(_ string: String) -> Date {
    NOAATimestamp.parse(string)!
}

func event(_ time: String, _ height: Double, _ kind: TideEvent.Kind) -> TideEvent {
    TideEvent(date: utc(time), heightMeters: height, kind: kind)
}

func forecast(
    events: [TideEvent],
    samples: [TideSample] = [],
    fetchedAt: Date? = nil,
    stationID: String = "TEST"
) -> TideForecast {
    let dates = events.map(\.date) + samples.map(\.date)
    let start = dates.min() ?? Date(timeIntervalSince1970: 0)
    let end = dates.max() ?? start
    return TideForecast(
        stationID: stationID,
        datum: "MLLW",
        fetchedAt: fetchedAt ?? start,
        coverage: DateInterval(start: start.addingTimeInterval(-3600), end: end.addingTimeInterval(3600)),
        events: events,
        samples: samples,
        curve: samples.isEmpty ? .unavailable(reason: "test") : .available(intervalMinutes: 15)
    )
}

let santaMonica = TideStation(
    id: "9410840", noaaName: "Santa Monica, Municipal Pier", state: "CA",
    latitude: 34.0083, longitude: -118.5, kind: .reference,
    referenceStationID: nil, timeZoneIdentifier: "America/Los_Angeles"
)

let kingHarbor = TideStation(
    id: "9410738", noaaName: "King Harbor, Santa Monica Bay", state: "CA",
    latitude: 33.8467, longitude: -118.3983, kind: .subordinate,
    referenceStationID: "9410660", timeZoneIdentifier: "America/Los_Angeles"
)

/// Serves canned responses keyed by the request's `interval` query value.
actor MockTransport: HTTPTransport {
    enum Reply {
        case body(Data, status: Int)
        case failure(URLError.Code)
    }

    private var replies: [String: [Reply]]
    private(set) var requests: [URL] = []
    private let delay: Duration?

    init(replies: [String: [Reply]], delay: Duration? = nil) {
        self.replies = replies
        self.delay = delay
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        requests.append(url)
        if let delay { try await Task.sleep(for: delay) }
        let interval = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "interval" }?.value ?? ""
        var queue = replies[interval] ?? []
        guard !queue.isEmpty else { throw URLError(.badServerResponse) }
        let reply = queue.count > 1 ? queue.removeFirst() : queue[0]
        replies[interval] = queue
        switch reply {
        case let .body(data, status):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, response)
        case let .failure(code):
            throw URLError(code)
        }
    }

    var requestCount: Int { requests.count }
}

struct InstantSleeper: Sleeper {
    func sleep(seconds: Double) async throws {}
}

final class MemoryCache: ForecastCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: TideForecast] = [:]

    func load(stationID: String) -> TideForecast? { lock.withLock { storage[stationID] } }
    func save(_ forecast: TideForecast) throws { lock.withLock { storage[forecast.stationID] = forecast } }
    func removeAll() throws { lock.withLock { storage.removeAll() } }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ date: Date) { value = date }
    var now: Date { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value = value.addingTimeInterval(seconds) } }
}

extension String {
    /// ICU separates "AM"/"PM" with U+202F; compare with plain spaces.
    var nbspFree: String { replacingOccurrences(of: "\u{202F}", with: " ") }
}
