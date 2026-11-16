import Foundation
import Testing
@testable import TideKit

@Suite("Next/previous event selection")
struct EventSelectionTests {
    let events = [
        event("2026-11-16 04:14", 0.211, .low),
        event("2026-11-16 12:23", 1.106, .high),
        event("2026-11-16 15:28", 1.056, .low),
        event("2026-11-16 21:04", 1.262, .high),
    ]

    @Test func exactlyAtHighTheNextEventIsTheFollowingLow() {
        let instant = utc("2026-11-16 12:23")
        #expect(TideEngine.nextEvent(after: instant, in: events)?.kind == .low)
        #expect(TideEngine.event(at: instant, in: events)?.kind == .high)
        #expect(TideEngine.previousEvent(atOrBefore: instant, in: events)?.kind == .high)
    }

    @Test func justBeforeAndAfterHigh() {
        let high = utc("2026-11-16 12:23")
        #expect(TideEngine.nextEvent(after: high.addingTimeInterval(-1), in: events)?.date == high)
        #expect(TideEngine.nextEvent(after: high.addingTimeInterval(1), in: events)?.date == utc("2026-11-16 15:28"))
        #expect(TideEngine.event(at: high.addingTimeInterval(61), in: events) == nil)
        #expect(TideEngine.event(at: high.addingTimeInterval(-60), in: events)?.kind == .high)
    }

    @Test func nextEventFallsOnNextStationDay() throws {
        // 21:04 UTC = 13:04 PST; 23:00 PST on the 16th has its next event on the 17th (local).
        let all = events + [event("2026-11-17 08:51", 0.12, .low)]
        let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let lateEvening = utc("2026-11-17 07:00") // 23:00 PST Nov 16
        let next = try #require(TideEngine.nextEvent(after: lateEvening, in: all))
        #expect(next.date == utc("2026-11-17 08:51"))
        #expect(!StationDay.isSameDay(lateEvening, next.date, timeZone: la))
    }

    @Test func nextEventAcrossYearBoundary() {
        let year = [event("2026-12-31 22:10", 1.5, .high), event("2027-01-01 04:30", 0.1, .low)]
        #expect(TideEngine.nextEvent(after: utc("2026-12-31 23:59"), in: year)?.date == utc("2027-01-01 04:30"))
    }

    @Test func noNextEventPastTheData() {
        #expect(TideEngine.nextEvent(after: utc("2026-11-16 22:00"), in: events) == nil)
        #expect(TideEngine.nextEvent(after: .now, in: []) == nil)
    }

    @Test func eventsAreSortedRegardlessOfInputOrder() {
        let shuffled = forecast(events: events.reversed())
        #expect(shuffled.events == events)
    }
}

@Suite("Rising/falling")
struct TrendTests {
    @Test func highLowOnlyTrendFromOppositeBracketingEvents() {
        let f = forecast(events: [event("2026-11-16 04:14", 0.2, .low), event("2026-11-16 12:23", 1.1, .high)])
        #expect(TideEngine.trend(at: utc("2026-11-16 08:00"), forecast: f) == .rising)
        #expect(TideEngine.trend(at: utc("2026-11-16 12:23"), forecast: f) == .unknown) // no event after
        let g = forecast(events: f.events + [event("2026-11-16 15:28", 1.0, .low)])
        #expect(TideEngine.trend(at: utc("2026-11-16 12:23"), forecast: g) == .falling) // exactly at high
    }

    @Test func unknownBeforeFirstEvent() {
        let f = forecast(events: [event("2026-11-16 04:14", 0.2, .low), event("2026-11-16 12:23", 1.1, .high)])
        #expect(TideEngine.trend(at: utc("2026-11-16 01:00"), forecast: f) == .unknown)
    }

    @Test func unknownWhenEventsAreMissing() {
        // Two lows in a row: a high is missing from the data.
        let sameKind = forecast(events: [event("2026-11-16 04:00", 0.2, .low), event("2026-11-16 10:00", 0.3, .low)])
        #expect(TideEngine.trend(at: utc("2026-11-16 07:00"), forecast: sameKind) == .unknown)
        // A 20 h gap between extremes is not plausible; don't claim a direction.
        let gap = forecast(events: [event("2026-11-16 00:00", 0.2, .low), event("2026-11-16 20:00", 1.3, .high)])
        #expect(TideEngine.trend(at: utc("2026-11-16 10:00"), forecast: gap) == .unknown)
    }

    @Test func curveTrendUsesSampleSlope() {
        let samples = [
            TideSample(date: utc("2026-11-16 10:00"), heightMeters: 0.80),
            TideSample(date: utc("2026-11-16 10:15"), heightMeters: 0.85),
            TideSample(date: utc("2026-11-16 10:30"), heightMeters: 0.84),
        ]
        let f = forecast(events: [], samples: samples)
        #expect(TideEngine.trend(at: utc("2026-11-16 10:07"), forecast: f) == .rising)
        #expect(TideEngine.trend(at: utc("2026-11-16 10:20"), forecast: f) == .falling)
        #expect(TideEngine.trend(at: utc("2026-11-16 10:15"), forecast: f) == .falling) // on a sample: next segment
    }

    @Test func realReferenceStationTrendMatchesEvents() throws {
        let events = try NOAADecoder.events(from: Fixture.data("santamonica_9410840_hilo"))
        let samples = try NOAADecoder.samples(from: Fixture.data("santamonica_9410840_15min"))
        let f = forecast(events: events, samples: samples)
        // Halfway between every consecutive opposite pair, curve and events must agree.
        for (a, b) in zip(events, events.dropFirst()) where a.kind != b.kind {
            let mid = Date(timeIntervalSince1970: (a.date.timeIntervalSince1970 + b.date.timeIntervalSince1970) / 2)
            guard mid <= samples.last!.date else { continue }
            #expect(TideEngine.trend(at: mid, forecast: f) == (a.kind == .low ? .rising : .falling))
        }
    }
}

@Suite("Heights")
struct HeightTests {
    let samples = [
        TideSample(date: utc("2026-11-16 10:00"), heightMeters: -0.20),
        TideSample(date: utc("2026-11-16 10:15"), heightMeters: 0.10),
        TideSample(date: utc("2026-11-16 12:00"), heightMeters: 0.50), // 1h45 gap
    ]

    @Test func interpolatesOnlyBetweenAdjacentSamples() throws {
        let value = try #require(TideEngine.interpolatedSampleHeight(at: utc("2026-11-16 10:05"), samples: samples))
        #expect(abs(value - (-0.10)) < 1e-9)
        #expect(TideEngine.interpolatedSampleHeight(at: utc("2026-11-16 10:15"), samples: samples) == 0.10)
    }

    @Test func neverExtrapolatesOrBridgesGaps() {
        #expect(TideEngine.interpolatedSampleHeight(at: utc("2026-11-16 09:59"), samples: samples) == nil)
        #expect(TideEngine.interpolatedSampleHeight(at: utc("2026-11-16 12:01"), samples: samples) == nil)
        #expect(TideEngine.interpolatedSampleHeight(at: utc("2026-11-16 11:00"), samples: samples) == nil)
    }

    @Test func highLowOnlyForecastHasHeightsOnlyAtEvents() {
        let f = forecast(events: [event("2026-11-16 04:14", 0.211, .low), event("2026-11-16 12:23", 1.106, .high)])
        #expect(TideEngine.height(at: utc("2026-11-16 08:00"), forecast: f) == nil)
        let atLow = TideEngine.height(at: utc("2026-11-16 04:14"), forecast: f)
        #expect(atLow == HeightReading(heightMeters: 0.211, source: .event(.low)))
    }

    @Test func eventHeightWinsOverSampleNearAnEvent() {
        let f = forecast(events: [event("2026-11-16 10:15", 0.11, .low)], samples: samples)
        #expect(TideEngine.height(at: utc("2026-11-16 10:15"), forecast: f)?.source == .event(.low))
        #expect(TideEngine.height(at: utc("2026-11-16 10:05"), forecast: f)?.source == .interpolatedBetweenSamples)
    }

    @Test func negativeHeightsAndUnitConversion() {
        #expect(abs(HeightUnit.feet.value(fromMeters: 0.3048) - 1) < 1e-12)
        #expect(abs(HeightUnit.feet.value(fromMeters: -0.2) - (-0.656168)) < 1e-6)
        #expect(HeightUnit.meters.value(fromMeters: -0.2) == -0.2)
        let format = TideFormat(timeZone: .gmt, unit: .feet, locale: Locale(identifier: "en_US"))
        #expect(format.height(-0.2) == "-0.7 ft")
        #expect(TideFormat(timeZone: .gmt, unit: .meters, locale: Locale(identifier: "en_US")).height(1.262) == "1.3 m")
    }

    @Test func normalizedLevelIsClampedAndSafe() {
        #expect(TideEngine.normalizedLevel(0.5, within: 0...1) == 0.5)
        #expect(TideEngine.normalizedLevel(-3, within: 0...1) == 0)
        #expect(TideEngine.normalizedLevel(9, within: 0...1) == 1)
        #expect(TideEngine.normalizedLevel(2, within: 2...2) == 0.5)
    }

    @Test func heightRangeUsesEventsAndSamplesInWindow() throws {
        let f = forecast(events: [event("2026-11-16 10:15", 0.11, .low)], samples: samples)
        let range = try #require(TideEngine.heightRange(in: DateInterval(start: utc("2026-11-16 09:00"), end: utc("2026-11-16 11:00")), forecast: f))
        #expect(range == -0.2...0.11)
    }
}

@Suite("Station days, time zones and DST")
struct StationDayTests {
    let la = TimeZone(identifier: "America/Los_Angeles")!

    @Test func springForwardDayIs23Hours() {
        let day = StationDay.dayInterval(containing: utc("2026-03-08 12:00"), timeZone: la)
        #expect(day.duration == 23 * 3600)
        #expect(day.start == utc("2026-03-08 08:00"))
    }

    @Test func fallBackDayIs25Hours() {
        let day = StationDay.dayInterval(containing: utc("2026-11-01 12:00"), timeZone: la)
        #expect(day.duration == 25 * 3600)
    }

    @Test func stationTimeIgnoresDeviceTimeZone() {
        // The same instant reads as station time regardless of where the user is.
        let instant = utc("2026-11-16 21:04")
        let us = Locale(identifier: "en_US")
        #expect(TideFormat(timeZone: la, unit: .feet, locale: us).time(instant).nbspFree == "1:04 PM")
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        #expect(TideFormat(timeZone: honolulu, unit: .feet, locale: us).time(instant).nbspFree == "11:04 AM")
    }

    @Test func formattingAcrossDSTTransition() {
        let us = Locale(identifier: "en_US")
        let format = TideFormat(timeZone: la, unit: .feet, locale: us)
        #expect(format.time(utc("2026-03-08 09:59")).nbspFree == "1:59 AM")
        #expect(format.time(utc("2026-03-08 10:00")).nbspFree == "3:00 AM")
        #expect(format.zoneAbbreviation(at: utc("2026-03-08 09:59")) == "PST")
        #expect(format.zoneAbbreviation(at: utc("2026-03-08 10:00")) == "PDT")
    }

    @Test func userLocaleChangesClockStyleNotZone() {
        let instant = utc("2026-11-16 21:04")
        #expect(TideFormat(timeZone: la, unit: .feet, locale: Locale(identifier: "en_GB")).time(instant) == "13:04")
    }

    @Test func midnightCrossingInStationZone() {
        let format = TideFormat(timeZone: la, unit: .feet, locale: Locale(identifier: "en_US"))
        // 07:30 UTC Nov 17 is still Nov 16 in Los Angeles.
        #expect(format.day(utc("2026-11-17 07:30")) == "Mon, Nov 16")
        #expect(format.day(utc("2026-11-17 08:30")) == "Tue, Nov 17")
    }

    @Test func invalidTimeZoneIsNotSilentlyReplaced() {
        let broken = TideStation(
            id: "X", noaaName: "Nowhere", state: "CA", latitude: 0, longitude: 0, kind: .reference,
            referenceStationID: nil, timeZoneIdentifier: "Mars/Olympus_Mons"
        )
        #expect(broken.timeZone == nil)
    }

    @Test func differentEventCountsPerDay() throws {
        // Real data: Santa Monica has only 2 extremes on some days and 4 on others.
        let events = try NOAADecoder.events(from: Fixture.data("santamonica_9410840_hilo"))
        var counts: [Int] = []
        var day = StationDay.dayInterval(containing: utc("2026-11-15 12:00"), timeZone: la)
        for _ in 0..<3 {
            counts.append(TideEngine.events(in: day, from: events).count)
            day = StationDay.dayInterval(containing: day.end.addingTimeInterval(60), timeZone: la)
        }
        #expect(Set(counts).count > 1, "expected varying event counts, got \(counts)")
    }
}

@Suite("Time zone resolver")
struct TimeZoneResolverTests {
    @Test(arguments: [
        ("MA", 42.35, -71.05, "America/New_York"),
        ("TX", 29.73, -93.87, "America/Chicago"), // Sabine Pass: NOAA tags −5, civil time is Central
        ("FL", 27.88, -82.85, "America/New_York"), // Indian Rocks Beach: NOAA tags −6
        ("FL", 30.40, -87.21, "America/Chicago"), // Pensacola
        ("AK", 60.47, -148.0, "America/Anchorage"), // Port Nellie Juan: NOAA tags −10
        ("AK", 56.57, -169.55, "America/Anchorage"), // St. George, Pribilofs
        ("AK", 51.86, -176.63, "America/Adak"),
        ("AK", 52.84, 173.19, "America/Adak"), // Attu, east longitude
        ("HI", 23.87, -166.28, "Pacific/Honolulu"),
        ("PR", 18.46, -66.12, "America/Puerto_Rico"),
        ("GU", 13.44, 144.66, "Pacific/Guam"),
    ])
    func resolves(state: String, latitude: Double, longitude: Double, expected: String) {
        #expect(StationTimeZoneResolver.timeZoneIdentifier(state: state, latitude: latitude, longitude: longitude) == expected)
    }

    @Test func unsupportedGeographyIsExcluded() {
        #expect(StationTimeZoneResolver.timeZoneIdentifier(state: "FM", latitude: 7, longitude: 134) == nil)
        #expect(StationTimeZoneResolver.timeZoneIdentifier(state: "", latitude: 0, longitude: 0) == nil)
    }
}
