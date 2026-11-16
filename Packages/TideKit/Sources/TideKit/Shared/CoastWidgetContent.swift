import Foundation

/// Everything a widget shows at one timeline instant, derived only from cached NOAA
/// predictions. Pure and testable; the widget views just render it.
public struct CoastWidgetContent: Sendable {
    public enum State: Sendable {
        /// No coast chosen yet.
        case unconfigured
        /// Coast chosen, but no usable predictions at this instant.
        case unavailable(station: TideStation, lastUpdated: Date?)
        case ready(Ready)
    }

    public struct Ready: Sendable {
        public let station: TideStation
        public let next: TideEvent
        public let following: TideEvent?
        public let trend: TideTrend
        public let headline: String
        public let nextTime: String
        public let nextKindWord: String
        public let nextHeight: String
        public let accessibilityLabel: String
        /// Set when predictions are older than the aging threshold.
        public let agingNote: String?
        /// Normalised predicted water level at this instant for the illustration, or
        /// `nil` when NOAA publishes no height here (high/low-only stations).
        public let waterLevel: Double?
        public let rhythm: Rhythm
    }

    /// The data for the medium widget's tide-rhythm strip.
    public struct Rhythm: Sendable {
        public let window: DateInterval
        public let events: [TideEvent]
        public let samples: [TideSample]
        public let range: ClosedRange<Double>
        public let now: Date
        public let startLabel: String
        public let endLabel: String
    }

    public let date: Date
    public let state: State

    public static let rhythmLookback: TimeInterval = 2 * 3600
    public static let rhythmSpan: TimeInterval = 24 * 3600

    public init(date: Date, station: TideStation?, forecast: TideForecast?, unit: HeightUnit, locale: Locale = .autoupdatingCurrent) {
        self.date = date
        guard let station else { state = .unconfigured; return }
        guard let forecast, forecast.stationID == station.id, let zone = station.timeZone else {
            state = .unavailable(station: station, lastUpdated: forecast?.fetchedAt)
            return
        }
        let moment = TideMoment(forecast: forecast, instant: date)
        guard moment.freshness.isUsable, let next = moment.nextEvent else {
            state = .unavailable(station: station, lastUpdated: forecast.fetchedAt)
            return
        }
        let format = TideFormat(timeZone: zone, unit: unit, locale: locale)
        let following = TideEngine.nextEvent(after: next.date, in: forecast.events)

        // Hour-aligned so the strip's end labels read as clean clock hours.
        let windowStart = format.calendar.dateInterval(of: .hour, for: date.addingTimeInterval(-Self.rhythmLookback))?.start
            ?? date.addingTimeInterval(-Self.rhythmLookback)
        let window = DateInterval(start: windowStart, duration: Self.rhythmSpan)
        let events = TideEngine.events(in: window, from: forecast.events)
        let samples = forecast.hasCurve
            ? forecast.samples.filter { $0.date >= window.start.addingTimeInterval(-3600) && $0.date <= window.end.addingTimeInterval(3600) }
            : []
        let range = TideEngine.heightRange(in: window, forecast: forecast) ?? (next.heightMeters...next.heightMeters)

        var aging: String?
        if case let .aging(lastUpdated) = moment.freshness {
            aging = "Updated \(format.day(lastUpdated))"
        }
        let kindWord = next.kind == .high ? "High" : "Low"
        let level = moment.height.map { TideEngine.normalizedLevel($0.heightMeters, within: range) }
        var hourStyle = Date.FormatStyle(locale: locale, calendar: format.calendar).hour(.defaultDigits(amPM: .abbreviated))
        hourStyle.timeZone = zone
        var dayHourStyle = hourStyle.weekday(.abbreviated)
        dayHourStyle.timeZone = zone
        state = .ready(Ready(
            station: station,
            next: next,
            following: following,
            trend: moment.trend,
            headline: format.eventHeadline(next),
            nextTime: format.time(next.date),
            nextKindWord: kindWord,
            nextHeight: format.height(next.heightMeters),
            accessibilityLabel: "\(station.displayName.title). \(format.eventAccessibilityLabel(next))"
                + (moment.trend == .unknown ? "" : " Tide \(moment.trend.rawValue).")
                + (aging.map { " \($0)." } ?? ""),
            agingNote: aging,
            waterLevel: level,
            rhythm: Rhythm(
                window: window, events: events, samples: samples, range: range, now: date,
                startLabel: window.start.formatted(hourStyle),
                endLabel: StationDay.isSameDay(window.start, window.end, timeZone: zone)
                    ? window.end.formatted(hourStyle) : window.end.formatted(dayHourStyle)
            )
        ))
    }
}
