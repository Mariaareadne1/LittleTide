import Foundation
import Testing
@testable import TideKit

@Suite("Widget content")
struct WidgetContentTests {
    let us = Locale(identifier: "en_US")

    func realForecast(fetchedAt: Date) throws -> TideForecast {
        let events = try NOAADecoder.events(from: Fixture.data("santamonica_9410840_hilo"))
        let samples = try NOAADecoder.samples(from: Fixture.data("santamonica_9410840_15min"))
        return TideForecast(
            stationID: santaMonica.id, datum: "MLLW", fetchedAt: fetchedAt,
            coverage: DateInterval(start: events.first!.date, end: events.last!.date),
            events: events, samples: samples, curve: .available(intervalMinutes: 15)
        )
    }

    @Test func readyContentMatchesNOAAEvent() throws {
        let now = utc("2026-11-16 18:20") // 10:20 PST
        let content = CoastWidgetContent(date: now, station: santaMonica, forecast: try realForecast(fetchedAt: now), unit: .feet, locale: us)
        guard case let .ready(ready) = content.state else { Issue.record("not ready"); return }
        #expect(ready.headline.nbspFree == "High at 1:04 PM")
        #expect(ready.nextHeight == "4.1 ft")
        #expect(ready.trend == .rising)
        #expect(ready.agingNote == nil)
        #expect(ready.waterLevel != nil)
        #expect(ready.rhythm.startLabel.nbspFree == "8 AM")
        #expect(ready.rhythm.endLabel.nbspFree == "Tue 8 AM")
        #expect(ready.accessibilityLabel.contains("predicted height 4.1 feet"))
    }

    @Test func unconfiguredAndMismatchedStation() throws {
        let now = utc("2026-11-16 18:20")
        if case .unconfigured = CoastWidgetContent(date: now, station: nil, forecast: nil, unit: .feet).state {} else { Issue.record("expected unconfigured") }
        // A forecast for another station must never be shown under this station's name.
        let other = try realForecast(fetchedAt: now)
        if case .unavailable = CoastWidgetContent(date: now, station: kingHarbor, forecast: other, unit: .feet).state {} else { Issue.record("expected unavailable") }
    }

    @Test func expiredForecastIsUnavailableAndAgingIsLabelled() throws {
        let fetched = utc("2026-11-15 00:00")
        let forecast = try realForecast(fetchedAt: fetched)
        if case .unavailable = CoastWidgetContent(date: utc("2026-11-19 12:00"), station: santaMonica, forecast: forecast, unit: .feet).state {} else {
            Issue.record("expected unavailable past the last event")
        }
        guard case let .ready(ready) = CoastWidgetContent(date: utc("2026-11-16 18:20"), station: santaMonica, forecast: forecast, unit: .feet, locale: us).state else {
            Issue.record("not ready"); return
        }
        #expect(ready.agingNote == "Updated Sat, Nov 14") // 00:00 UTC Nov 15 is Nov 14 in Los Angeles
    }

    @Test func highLowOnlyHasNoInventedLevelOrCurve() throws {
        let events = try NOAADecoder.events(from: Fixture.data("kingharbor_9410738_hilo"))
        let forecast = TideForecast(
            stationID: kingHarbor.id, datum: "MLLW", fetchedAt: utc("2026-11-16 18:00"),
            coverage: DateInterval(start: events.first!.date, end: events.last!.date),
            events: events, samples: [], curve: .unavailable(reason: "subordinate")
        )
        guard case let .ready(ready) = CoastWidgetContent(date: utc("2026-11-16 18:20"), station: kingHarbor, forecast: forecast, unit: .feet).state else {
            Issue.record("not ready"); return
        }
        #expect(ready.waterLevel == nil)
        #expect(ready.rhythm.samples.isEmpty)
        #expect(!ready.rhythm.events.isEmpty)
    }
}
