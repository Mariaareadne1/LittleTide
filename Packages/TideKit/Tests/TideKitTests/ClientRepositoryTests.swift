import Foundation
import Testing
@testable import TideKit

@Suite("NOAA client")
struct NOAAClientTests {
    let now = utc("2026-11-16 18:20")

    func client(_ transport: MockTransport) -> NOAATideClient {
        NOAATideClient(transport: transport, sleeper: InstantSleeper())
    }

    @Test func referenceStationGetsEventsAndCurve() async throws {
        let transport = MockTransport(replies: [
            "hilo": [.body(try Fixture.data("santamonica_9410840_hilo"), status: 200)],
            "15": [.body(try Fixture.data("santamonica_9410840_15min"), status: 200)],
        ])
        let f = try await client(transport).fetchForecast(for: santaMonica, now: now)
        #expect(f.hasCurve)
        #expect(f.curve == .available(intervalMinutes: 15))
        #expect(f.datum == "MLLW")
        #expect(f.fetchedAt == now)
        #expect(await transport.requestCount == 2)
    }

    @Test func subordinateStationNeverRequestsACurve() async throws {
        let transport = MockTransport(replies: ["hilo": [.body(try Fixture.data("kingharbor_9410738_hilo"), status: 200)]])
        let f = try await client(transport).fetchForecast(for: kingHarbor, now: now)
        #expect(!f.hasCurve)
        #expect(f.samples.isEmpty)
        #expect(await transport.requestCount == 1)
    }

    @Test func rejectedCurveDegradesToHighLowOnly() async throws {
        let transport = MockTransport(replies: [
            "hilo": [.body(try Fixture.data("santamonica_9410840_hilo"), status: 200)],
            "15": [.body(try Fixture.data("kingharbor_9410738_15min_error"), status: 200)],
        ])
        let f = try await client(transport).fetchForecast(for: santaMonica, now: now)
        #expect(!f.hasCurve)
        #expect(f.curve == .unavailable(reason: "NOAA does not provide interval predictions for this station."))
        #expect(!f.events.isEmpty)
    }

    @Test func throttlingIsRetriedWithBackoffThenSucceeds() async throws {
        let transport = MockTransport(replies: [
            "hilo": [
                .body(try Fixture.data("error_throttled_403"), status: 403),
                .body(Data(), status: 503),
                .body(try Fixture.data("kingharbor_9410738_hilo"), status: 200),
            ],
        ])
        let f = try await client(transport).fetchForecast(for: kingHarbor, now: now)
        #expect(!f.events.isEmpty)
        #expect(await transport.requestCount == 3)
    }

    @Test func retriesAreBounded() async throws {
        let transport = MockTransport(replies: ["hilo": [.body(Data(), status: 429)]])
        await #expect(throws: NOAAError.throttled) { try await client(transport).fetchForecast(for: kingHarbor, now: now) }
        #expect(await transport.requestCount == 3) // 1 + 2 retries
    }

    @Test func offlineIsNotRetried() async throws {
        let transport = MockTransport(replies: ["hilo": [.failure(.notConnectedToInternet)]])
        await #expect(throws: NOAAError.noConnection) { try await client(transport).fetchForecast(for: kingHarbor, now: now) }
        #expect(await transport.requestCount == 1)
    }

    @Test func timeoutIsReported() async throws {
        let transport = MockTransport(replies: ["hilo": [.failure(.timedOut)]])
        await #expect(throws: NOAAError.timedOut) { try await client(transport).fetchForecast(for: kingHarbor, now: now) }
    }

    @Test func wrongStationIDIsRejected() async throws {
        let transport = MockTransport(replies: ["hilo": [.body(try Fixture.data("error_bad_station"), status: 400)]])
        await #expect(throws: NOAAError.rejected(message: "The station is not a valid station or there is system error.")) {
            try await client(transport).fetchForecast(for: kingHarbor, now: now)
        }
    }

    @Test func requestWindowIsHourAlignedAroundNow() {
        let start = NOAATideClient.requestStart(for: utc("2026-11-16 18:20"))
        #expect(start == utc("2026-11-15 06:00"))
    }
}

@Suite("Repository: cache, staleness, offline")
struct RepositoryTests {
    func makeRepository(_ transport: MockTransport, cache: MemoryCache = MemoryCache(), clock: TestClock) -> TideRepository {
        TideRepository(client: NOAATideClient(transport: transport, sleeper: InstantSleeper()), cache: cache, now: { clock.now })
    }

    func hiloFixture() throws -> [String: [MockTransport.Reply]] {
        ["hilo": [.body(try Fixture.data("kingharbor_9410738_hilo"), status: 200)]]
    }

    @Test func freshCacheAvoidsTheNetwork() async throws {
        let clock = TestClock(utc("2026-11-15 06:00"))
        let transport = MockTransport(replies: try hiloFixture())
        let cache = MemoryCache()
        let longReach = forecast(
            events: [event("2026-11-15 00:00", 0, .low), event("2026-11-22 00:00", 1, .high)],
            fetchedAt: clock.now.addingTimeInterval(-600),
            stationID: kingHarbor.id
        )
        try cache.save(longReach)
        let result = try await makeRepository(transport, cache: cache, clock: clock).forecast(for: kingHarbor)
        #expect(result.origin == .cache)
        #expect(await transport.requestCount == 0)
    }

    @Test func offlineFallsBackToRelevantCacheAndSaysSo() async throws {
        let clock = TestClock(utc("2026-11-15 06:00"))
        let cache = MemoryCache()
        let online = MockTransport(replies: try hiloFixture())
        _ = try await makeRepository(online, cache: cache, clock: clock).forecast(for: kingHarbor)

        clock.advance(4 * 3600)
        let offline = MockTransport(replies: ["hilo": [.failure(.notConnectedToInternet)]])
        let result = try await makeRepository(offline, cache: cache, clock: clock).forecast(for: kingHarbor)
        #expect(result.origin == .cacheAfterFailure(.noConnection))
        #expect(result.forecast.fetchedAt == utc("2026-11-15 06:00"))
    }

    @Test func expiredCacheIsNotPresentedAsCurrent() async throws {
        let clock = TestClock(utc("2026-11-15 06:00"))
        let cache = MemoryCache()
        _ = try await makeRepository(MockTransport(replies: try hiloFixture()), cache: cache, clock: clock).forecast(for: kingHarbor)
        clock.advance(10 * 24 * 3600) // past the last cached event
        let offline = MockTransport(replies: ["hilo": [.failure(.notConnectedToInternet)]])
        await #expect(throws: NOAAError.noConnection) {
            try await makeRepository(offline, cache: cache, clock: clock).forecast(for: kingHarbor)
        }
        let stale = try #require(cache.load(stationID: kingHarbor.id))
        #expect(!TideEngine.freshness(of: stale, at: clock.now).isUsable)
    }

    @Test func concurrentRequestsForOneStationShareOneFetch() async throws {
        let clock = TestClock(utc("2026-11-15 06:00"))
        let transport = MockTransport(replies: try hiloFixture(), delay: .milliseconds(50))
        let repository = makeRepository(transport, clock: clock)
        async let a = repository.forecast(for: kingHarbor)
        async let b = repository.forecast(for: kingHarbor)
        async let c = repository.forecast(for: kingHarbor)
        _ = try await (a, b, c)
        #expect(await transport.requestCount == 1)
    }

    @Test func manualRefreshIsRateLimited() async throws {
        let clock = TestClock(utc("2026-11-15 06:00"))
        let repository = makeRepository(MockTransport(replies: try hiloFixture()), clock: clock)
        let cached = forecast(events: [event("2026-11-20 00:00", 1, .high)], fetchedAt: clock.now.addingTimeInterval(-30))
        #expect(await repository.needsRefresh(cached, manual: true) == false)
        clock.advance(60)
        #expect(await repository.needsRefresh(cached, manual: true) == true)
    }

    @Test func automaticRefreshWhenOldOrShort() async throws {
        let clock = TestClock(utc("2026-11-15 06:00"))
        let repository = makeRepository(MockTransport(replies: [:]), clock: clock)
        let longReach = forecast(events: [event("2026-11-15 00:00", 0, .low), event("2026-11-22 00:00", 1, .high)], fetchedAt: clock.now)
        #expect(await repository.needsRefresh(longReach, manual: false) == false)
        let shortReach = forecast(events: [event("2026-11-15 00:00", 0, .low), event("2026-11-16 00:00", 1, .high)], fetchedAt: clock.now)
        #expect(await repository.needsRefresh(shortReach, manual: false) == true)
        clock.advance(4 * 3600)
        #expect(await repository.needsRefresh(longReach, manual: false) == true)
        #expect(await repository.needsRefresh(nil, manual: false) == true)
    }

    @Test func freshnessStates() {
        let f = forecast(events: [event("2026-11-15 00:00", 0, .low), event("2026-11-16 00:00", 1, .high)], fetchedAt: utc("2026-11-15 00:00"))
        #expect(TideEngine.freshness(of: f, at: utc("2026-11-15 01:00")) == .current)
        #expect(TideEngine.freshness(of: f, at: utc("2026-11-15 13:00")) == .aging(lastUpdated: utc("2026-11-15 00:00")))
        #expect(TideEngine.freshness(of: f, at: utc("2026-11-16 00:00")) == .expired(lastUpdated: utc("2026-11-15 00:00")))
    }
}

@Suite("File cache schema")
struct FileCacheTests {
    func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("lt-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func roundTripsAForecast() throws {
        let cache = FileForecastCache(directory: temporaryDirectory())
        let f = forecast(events: [event("2026-11-15 00:00", 0, .low)], samples: [TideSample(date: utc("2026-11-15 00:00"), heightMeters: 0)])
        try cache.save(f)
        #expect(cache.load(stationID: "TEST") == f)
        try cache.removeAll()
        #expect(cache.load(stationID: "TEST") == nil)
    }

    @Test func discardsOtherSchemaVersionsAndCorruptFiles() throws {
        let directory = temporaryDirectory()
        let cache = FileForecastCache(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let f = forecast(events: [event("2026-11-15 00:00", 0, .low)])
        let future = FileForecastCache.Envelope(schemaVersion: 99, forecast: f)
        try FileForecastCache.encoder.encode(future).write(to: cache.fileURL(for: "TEST"))
        #expect(cache.load(stationID: "TEST") == nil)
        #expect(!FileManager.default.fileExists(atPath: cache.fileURL(for: "TEST").path))
        try Data("{".utf8).write(to: cache.fileURL(for: "TEST"))
        #expect(cache.load(stationID: "TEST") == nil)
    }

    @Test func fileNamesCannotEscapeTheDirectory() {
        let cache = FileForecastCache(directory: URL(fileURLWithPath: "/tmp/x"))
        #expect(cache.fileURL(for: "../../etc/passwd").lastPathComponent == "forecast-etcpasswd.json")
    }

    @Test func settingsRoundTripAndSurviveCorruption() throws {
        let defaults = try #require(UserDefaults(suiteName: "lt-test-\(UUID().uuidString)"))
        let settings = SharedSettings(defaults: defaults)
        settings.setSelectedStation(santaMonica)
        settings.setUnit(.meters)
        #expect(settings.selectedStation == santaMonica)
        #expect(settings.unit == .meters)
        defaults.set(Data("garbage".utf8), forKey: SharedSettings.Key.selectedStation)
        #expect(settings.selectedStation == nil)
    }
}

@Suite("Station catalog")
struct CatalogTests {
    let catalog = try! StationCatalog.bundled()

    @Test func bundledCatalogIsUSOnlyWithValidZones() {
        #expect(catalog.stations.count > 3000)
        #expect(catalog.stations.allSatisfy { StationTimeZoneResolver.supportedStates.contains($0.state) })
        #expect(catalog.stations.allSatisfy { $0.timeZone != nil })
        #expect(catalog.station(id: "8218447") == nil) // Wales Island, British Columbia
        #expect(catalog.station(id: "1910000") == nil) // Suva, Fiji
    }

    @Test func searchByNameStateAndID() {
        #expect(catalog.search("santa monica").first?.id == "9410840")
        #expect(catalog.search("9447130").first?.id == "9447130")
        #expect(catalog.search("bar harbor maine").first?.id == "8413320")
        #expect(catalog.search("charleston or").first?.id == "9432780")
        #expect(catalog.search("MONTEREY").contains { $0.id == "9413450" })
    }

    @Test func noMatchesIsEmptyNotAGuess() {
        #expect(catalog.search("zzqx beach").isEmpty)
        #expect(catalog.search("   ").isEmpty)
    }

    @Test func displayNamesAreTidied() {
        let monterey = StationDisplayName(noaaName: "MONTEREY, MONTEREY BAY", state: "CA")
        #expect(monterey.title == "Monterey" && monterey.subtitle == "Monterey Bay · CA")
        let sanDiego = StationDisplayName(noaaName: "SAN DIEGO (Broadway)", state: "CA")
        #expect(sanDiego.title == "San Diego" && sanDiego.subtitle == "Broadway · CA")
        #expect(StationDisplayName(noaaName: "S.C.L. RR. bridge", state: "GA").title == "S.C.L. RR. bridge")
        #expect(StationDisplayName(noaaName: "BOSTON", state: "MA").subtitle == "MA")
        #expect(StationDisplayName(noaaName: "CHARLESTON (Customhouse Wharf)", state: "SC").title == "Charleston")
        let sabine = StationDisplayName(noaaName: "Sabine Offshore Light (USCG S-1 Platform)", state: "TX")
        #expect(sabine.title == "Sabine Offshore Light" && sabine.subtitle == "USCG S-1 Platform · TX")
        let seattle = StationDisplayName(noaaName: "SEATTLE (Madison St.), Elliott Bay", state: "WA")
        #expect(seattle.title == "Seattle" && seattle.subtitle == "Madison St. · Elliott Bay · WA")
        // A parenthetical in the middle is part of the name and stays.
        #expect(StationDisplayName(noaaName: "Matanzas Pass (fixed bridge) Estero Island", state: "FL").title == "Matanzas Pass (fixed bridge) Estero Island")
    }
}


@Suite("Widget timeline planning")
struct WidgetPlannerTests {
    @Test func entriesFlipJustAfterEachEventAndAreBounded() {
        let now = utc("2026-11-16 00:00")
        let f = forecast(events: [
            event("2026-11-15 20:00", 0.2, .low), event("2026-11-16 04:14", 1.1, .high),
            event("2026-11-16 12:23", 0.3, .low), event("2026-11-17 02:00", 1.2, .high),
        ])
        let dates = WidgetTimelinePlanner.entryDates(for: f, now: now)
        #expect(dates.first == now)
        #expect(dates.contains(utc("2026-11-16 04:14").addingTimeInterval(1)))
        #expect(dates.contains(utc("2026-11-16 12:23").addingTimeInterval(1)))
        #expect(dates.count <= 60)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 < now.addingTimeInterval(24 * 3600) })
    }

    @Test func reloadNoLaterThanTheLastKnownEvent() {
        let now = utc("2026-11-16 00:00")
        let f = forecast(events: [event("2026-11-16 02:00", 1, .high)])
        #expect(WidgetTimelinePlanner.reloadDate(for: f, now: now) == utc("2026-11-16 02:00"))
        #expect(WidgetTimelinePlanner.reloadDate(for: nil, now: now) == now.addingTimeInterval(1800))
    }

    @Test func momentAtEachEntryNeverReportsAPastEventAsNext() {
        let now = utc("2026-11-16 00:00")
        let f = forecast(events: [event("2026-11-16 04:14", 1.1, .high), event("2026-11-16 12:23", 0.3, .low)])
        for date in WidgetTimelinePlanner.entryDates(for: f, now: now) {
            let moment = TideMoment(forecast: f, instant: date)
            if let next = moment.nextEvent { #expect(next.date > date) }
        }
    }
}
