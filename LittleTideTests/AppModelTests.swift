import XCTest
import TideKit
@testable import LittleTide

/// Serves a fixture per station after a per-station delay, to reproduce races.
private actor SlowTransport: HTTPTransport {
    let delays: [String: Duration]
    let bodies: [String: Data]
    init(delays: [String: Duration], bodies: [String: Data]) { self.delays = delays; self.bodies = bodies }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let station = items.first { $0.name == "station" }?.value ?? ""
        try await Task.sleep(for: delays[station] ?? .zero)
        return (bodies[station] ?? Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private final class MemoryCache: ForecastCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: TideForecast] = [:]
    func load(stationID: String) -> TideForecast? { lock.withLock { storage[stationID] } }
    func save(_ forecast: TideForecast) throws { lock.withLock { storage[forecast.stationID] = forecast } }
    func removeAll() throws { lock.withLock { storage.removeAll() } }
}

@MainActor
final class AppModelTests: XCTestCase {
    private func hilo(_ first: String, _ height: String) -> Data {
        Data(#"{"predictions":[{"t":"2026-11-16 12:00","v":"\#(height)","type":"H"},{"t":"\#(first)","v":"0.1","type":"L"},{"t":"2026-11-23 00:00","v":"1.0","type":"H"}]}"#.utf8)
    }

    private func station(_ id: String, kind: TideStation.Kind = .subordinate) -> TideStation {
        TideStation(id: id, noaaName: "Station \(id)", state: "CA", latitude: 34, longitude: -118, kind: kind,
                    referenceStationID: nil, timeZoneIdentifier: "America/Los_Angeles")
    }

    private func makeModel(transport: HTTPTransport, now: Date) -> (AppModel, UserDefaults) {
        let suite = "lt-model-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let repository = TideRepository(client: NOAATideClient(transport: transport, retryDelays: []), cache: MemoryCache(), now: { now })
        let model = AppModel(repository: repository, settings: SharedSettings(defaults: defaults), clock: .fixed(now), widgetReloader: {})
        return (model, defaults)
    }

    func testSlowResponseForPreviousCoastIsNeverShownUnderNewCoast() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-11-16T10:00:00Z")!
        let transport = SlowTransport(
            delays: ["SLOW": .milliseconds(600), "FAST": .milliseconds(50)],
            bodies: ["SLOW": hilo("2026-11-16 18:00", "9.9"), "FAST": hilo("2026-11-16 19:00", "2.2")]
        )
        let (model, _) = makeModel(transport: transport, now: now)

        model.select(station("SLOW"))
        try await Task.sleep(for: .milliseconds(100))
        model.select(station("FAST"))

        // Watch every state for a second: nothing for SLOW may appear while FAST is chosen.
        let deadline = Date().addingTimeInterval(1.2)
        while Date() < deadline {
            if let shown = model.forecastState.forecast {
                XCTAssertEqual(shown.stationID, "FAST", "previous coast's data appeared under the new coast")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(model.station?.id, "FAST")
        XCTAssertEqual(model.forecastState.forecast?.stationID, "FAST")
        XCTAssertEqual(model.forecastState.forecast?.events.first?.heightMeters, 2.2)
    }

    func testSelectionPersistsAcrossRelaunch() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-11-16T10:00:00Z")!
        let transport = SlowTransport(delays: [:], bodies: ["A": hilo("2026-11-16 18:00", "1.0")])
        let (model, defaults) = makeModel(transport: transport, now: now)
        model.select(station("A"))
        model.unit = .meters
        // A new model over the same storage, as after an app restart.
        let relaunched = AppModel(
            repository: TideRepository(client: NOAATideClient(transport: transport), cache: MemoryCache()),
            settings: SharedSettings(defaults: defaults), clock: .fixed(now), widgetReloader: {}
        )
        XCTAssertEqual(relaunched.station?.id, "A")
        XCTAssertEqual(relaunched.unit, .meters)
    }

    func testUnknownDeepLinkIsIgnored() {
        let (model, _) = makeModel(transport: SlowTransport(delays: [:], bodies: [:]), now: .now)
        model.handle(URL(string: "littletide://station/NOPE123")!)
        XCTAssertNil(model.station)
    }
}
