import Foundation
import Testing
@testable import TideKit

@Suite("Lock Screen widget text")
struct AccessoryFormatTests {
    @Test func circularFaceDropsTheMeridiem() {
        #expect(AccessoryText.shortTime("1:04\u{202F}PM") == "1:04")
        #expect(AccessoryText.shortTime("11:56 AM") == "11:56")
        #expect(AccessoryText.shortTime("13:04") == "13:04") // 24-hour locales unchanged
    }

    @Test func rectangularFaceReadsFromRealPredictions() throws {
        let events = try NOAADecoder.events(from: Fixture.data("santamonica_9410840_hilo"))
        let samples = try NOAADecoder.samples(from: Fixture.data("santamonica_9410840_15min"))
        let f = TideForecast(stationID: santaMonica.id, datum: "MLLW", fetchedAt: utc("2026-11-16 18:00"),
                             coverage: DateInterval(start: utc("2026-11-15 00:00"), end: utc("2026-11-18 00:00")),
                             events: events, samples: samples, curve: .available(intervalMinutes: 15))
        let content = CoastWidgetContent(date: utc("2026-11-16 18:20"), station: santaMonica, forecast: f, unit: .feet,
                                         locale: Locale(identifier: "en_US"))
        guard case let .ready(ready) = content.state else { Issue.record("expected ready"); return }
        #expect(ready.headline.nbspFree == "High at 1:04 PM")
        #expect(AccessoryText.detail(for: ready) == "Rising · 4.1 ft")
        #expect(AccessoryText.symbol(for: ready) == "arrow.up.right")
    }
}
