import Foundation
import Testing
@testable import TideKit

/// Real NOAA responses from three more coasts (recorded 2026-11-17; URLs in Fixtures/README.md).
/// Expected values were read from the raw fixtures, not computed by the code under test.
@Suite("Atlantic, Gulf and Alaska stations (real captured responses)")
struct RegionalFixtureTests {
    let us = Locale(identifier: "en_US")
    let newYork = TimeZone(identifier: "America/New_York")!
    let chicago = TimeZone(identifier: "America/Chicago")!
    let anchorage = TimeZone(identifier: "America/Anchorage")!

    // MARK: Atlantic — Chatham, MA (8447435), across the 2026-11-01 fall-back

    private func chatham() throws -> TideForecast {
        let events = try NOAADecoder.events(from: Fixture.data("chatham_8447435_dst_hilo"))
        let samples = try NOAADecoder.samples(from: Fixture.data("chatham_8447435_dst_15min"))
        return TideForecast(
            stationID: "8447435", datum: "MLLW", fetchedAt: utc("2026-10-31 00:00"),
            coverage: DateInterval(start: utc("2026-10-31 00:00"), end: utc("2026-11-03 00:00")),
            events: events, samples: samples, curve: .available(intervalMinutes: 15)
        )
    }

    @Test func fallBackDayHasFourEventsInStationTime() throws {
        let forecast = try chatham()
        let day = StationDay.dayInterval(containing: utc("2026-11-01 15:00"), timeZone: newYork)
        #expect(day.duration == 25 * 3600)
        let format = TideFormat(timeZone: newYork, unit: .feet, locale: us)
        let times = TideEngine.events(in: day, from: forecast.events).map { format.time($0.date).nbspFree }
        #expect(times == ["4:31 AM", "10:54 AM", "4:44 PM", "11:56 PM"])
        #expect(format.zoneAbbreviation(at: utc("2026-11-01 09:31")) == "EST")
    }

    @Test func lateEveningEventBelongsToThePreviousStationDay() throws {
        // 03:55 UTC on Nov 1 is 11:55 PM EDT on Oct 31.
        let forecast = try chatham()
        let low = try #require(forecast.events.first { $0.date == utc("2026-11-01 03:55") })
        let format = TideFormat(timeZone: newYork, unit: .feet, locale: us)
        #expect(format.day(low.date) == "Sat, Oct 31")
        let oct31 = StationDay.dayInterval(containing: utc("2026-10-31 16:00"), timeZone: newYork)
        #expect(TideEngine.events(in: oct31, from: forecast.events).contains(low))
    }

    @Test func curveIsContinuousThroughTheRepeatedHour() throws {
        // Samples are in UTC, so the repeated 1 AM hour neither duplicates nor drops a sample.
        let samples = try chatham().samples
        #expect(samples.count == 289)
        let steps = Set(zip(samples, samples.dropFirst()).map { $1.date.timeIntervalSince($0.date) })
        #expect(steps == [900])
    }

    @Test func curveAgreesWithPublishedExtremes() throws {
        let forecast = try chatham()
        for event in forecast.events {
            let near = forecast.samples.filter { abs($0.date.timeIntervalSince(event.date)) <= 15 * 60 }
            let extreme = event.kind == .high ? near.map(\.heightMeters).max() : near.map(\.heightMeters).min()
            let value = try #require(extreme)
            #expect(abs(value - event.heightMeters) < 0.03, "curve \(value) vs event \(event.heightMeters) at \(event.date)")
        }
    }

    @Test func trendFollowsTheCurveAroundTheChange() throws {
        let forecast = try chatham()
        #expect(TideEngine.trend(at: utc("2026-11-01 06:00"), forecast: forecast) == .rising) // after 11:55 PM low
        #expect(TideEngine.trend(at: utc("2026-11-01 12:00"), forecast: forecast) == .falling) // after 4:31 AM high
        let next = try #require(TideEngine.nextEvent(after: utc("2026-11-01 06:00"), in: forecast.events))
        #expect(next.date == utc("2026-11-01 09:31") && next.kind == .high)
    }

    // MARK: Gulf — Pensacola, FL (8729840), diurnal

    @Test func diurnalGulfStationHasOneHighAndOneLowPerDay() throws {
        let events = try NOAADecoder.events(from: Fixture.data("pensacola_8729840_hilo"))
        var day = StationDay.dayInterval(containing: utc("2026-11-16 18:00"), timeZone: chicago)
        for _ in 0..<3 {
            let kinds = TideEngine.events(in: day, from: events).map(\.kind)
            #expect(kinds == [.high, .low])
            day = StationDay.dayInterval(containing: day.end.addingTimeInterval(60), timeZone: chicago)
        }
        let format = TideFormat(timeZone: chicago, unit: .feet, locale: us)
        #expect(format.time(utc("2026-11-17 08:34")).nbspFree == "2:34 AM")
    }

    @Test func smallGulfRangeKeepsHighLowOnlyTrend() throws {
        let events = try NOAADecoder.events(from: Fixture.data("pensacola_8729840_hilo"))
        let forecast = forecast(events: events)
        #expect(TideEngine.trend(at: utc("2026-11-17 12:00"), forecast: forecast) == .falling)
        #expect(TideEngine.trend(at: utc("2026-11-17 22:00"), forecast: forecast) == .rising)
        // Hi/lo-only data: no height is invented between events.
        #expect(TideEngine.height(at: utc("2026-11-17 12:00"), forecast: forecast) == nil)
    }

    // MARK: Alaska — Juneau, AK (9452210), large range

    private func juneau() throws -> TideForecast {
        let events = try NOAADecoder.events(from: Fixture.data("juneau_9452210_hilo"))
        let samples = try NOAADecoder.samples(from: Fixture.data("juneau_9452210_15min"))
        return TideForecast(
            stationID: "9452210", datum: "MLLW", fetchedAt: utc("2026-11-16 00:00"),
            coverage: DateInterval(start: utc("2026-11-16 00:00"), end: utc("2026-11-18 00:00")),
            events: events, samples: samples, curve: .available(intervalMinutes: 15)
        )
    }

    @Test func largeAlaskanRangeFormatsInBothUnits() throws {
        let high = try #require(try juneau().events.first)
        #expect(high.heightMeters == 4.207)
        #expect(TideFormat(timeZone: anchorage, unit: .feet, locale: us).height(high.heightMeters) == "13.8 ft")
        #expect(TideFormat(timeZone: anchorage, unit: .meters, locale: us).height(high.heightMeters) == "4.2 m")
    }

    @Test func utcDateRollsBackToTheAlaskanDay() throws {
        // 02:12 UTC Nov 17 is 5:12 PM AKST on Nov 16.
        let format = TideFormat(timeZone: anchorage, unit: .feet, locale: us)
        #expect(format.day(utc("2026-11-17 02:12")) == "Mon, Nov 16")
        #expect(format.time(utc("2026-11-17 02:12")).nbspFree == "5:12 PM")
        let forecast = try juneau()
        let nov16 = StationDay.dayInterval(containing: utc("2026-11-16 20:00"), timeZone: anchorage)
        #expect(TideEngine.events(in: nov16, from: forecast.events).count == 4)
    }

    @Test func dayRangeSpansTheMixedSemidiurnalSwing() throws {
        let forecast = try juneau()
        let nov16 = StationDay.dayInterval(containing: utc("2026-11-16 20:00"), timeZone: anchorage)
        let range = try #require(TideEngine.heightRange(in: nov16, forecast: forecast))
        #expect(range.upperBound - range.lowerBound > 2.5) // 1.02 m low to 3.906 m high
        let level = TideEngine.normalizedLevel(3.906, within: range)
        #expect(level > 0.95 && level <= 1)
    }
}
