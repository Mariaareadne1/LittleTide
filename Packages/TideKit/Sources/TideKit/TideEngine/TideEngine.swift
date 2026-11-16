import Foundation

/// Pure, deterministic tide calculations. No networking, no clocks, no UI.
/// Every function takes the instant it reasons about as a parameter.
public enum TideEngine {
    /// Largest gap between two interval samples that may be interpolated across.
    /// NOAA 15-minute data has 15-minute gaps; anything wider means missing data.
    public static let maximumInterpolationGap: TimeInterval = 60 * 60

    /// Longest plausible span between consecutive high and low events. Diurnal stations
    /// can go ~13 h between extremes; a wider gap means events are missing, so the trend
    /// between them is not defensible.
    public static let maximumEventGap: TimeInterval = 16 * 60 * 60

    /// Within this distance of an event, the selected instant is considered to be "at" it.
    public static let eventMatchTolerance: TimeInterval = 60

    // MARK: Events

    /// First event strictly after `instant`.
    public static func nextEvent(after instant: Date, in events: [TideEvent]) -> TideEvent? {
        events.first { $0.date > instant }
    }

    /// Last event at or before `instant`.
    public static func previousEvent(atOrBefore instant: Date, in events: [TideEvent]) -> TideEvent? {
        events.last { $0.date <= instant }
    }

    /// The event that `instant` falls on, within `eventMatchTolerance`.
    public static func event(at instant: Date, in events: [TideEvent]) -> TideEvent? {
        events
            .filter { abs($0.date.timeIntervalSince(instant)) <= eventMatchTolerance }
            .min { abs($0.date.timeIntervalSince(instant)) < abs($1.date.timeIntervalSince(instant)) }
    }

    /// Events within `interval` (inclusive start, exclusive end).
    public static func events(in interval: DateInterval, from events: [TideEvent]) -> [TideEvent] {
        events.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    // MARK: Trend

    /// Predicted direction of the tide at `instant`.
    ///
    /// 1. With interval samples bracketing the instant, uses the sign of their slope.
    /// 2. Otherwise, uses the surrounding high/low events, but only when they are of
    ///    opposite kinds and close enough together that no event can be missing.
    /// 3. Otherwise returns `.unknown`.
    public static func trend(at instant: Date, forecast: TideForecast) -> TideTrend {
        if forecast.hasCurve, let slope = sampleSlope(at: instant, samples: forecast.samples), slope != 0 {
            return slope > 0 ? .rising : .falling
        }
        return eventTrend(at: instant, events: forecast.events)
    }

    static func eventTrend(at instant: Date, events: [TideEvent]) -> TideTrend {
        guard let previous = previousEvent(atOrBefore: instant, in: events),
              let next = nextEvent(after: instant, in: events),
              previous.kind != next.kind,
              next.date.timeIntervalSince(previous.date) <= maximumEventGap
        else { return .unknown }
        return previous.kind == .low ? .rising : .falling
    }

    static func sampleSlope(at instant: Date, samples: [TideSample]) -> Double? {
        guard let (lower, upper) = bracketingSamples(at: instant, samples: samples) else { return nil }
        if lower.date == upper.date {
            // Exactly on a sample: look at the following segment, else the preceding one.
            guard let index = samples.firstIndex(of: lower) else { return nil }
            if index + 1 < samples.count, samples[index + 1].date.timeIntervalSince(lower.date) <= maximumInterpolationGap {
                return samples[index + 1].heightMeters - lower.heightMeters
            }
            if index > 0, lower.date.timeIntervalSince(samples[index - 1].date) <= maximumInterpolationGap {
                return lower.heightMeters - samples[index - 1].heightMeters
            }
            return nil
        }
        return upper.heightMeters - lower.heightMeters
    }

    // MARK: Heights

    /// A displayable height at `instant`, with its provenance, or `nil` when the
    /// forecast cannot support one. Never extrapolates and never fabricates a curve
    /// from high/low events.
    public static func height(at instant: Date, forecast: TideForecast) -> HeightReading? {
        if let event = event(at: instant, in: forecast.events) {
            return HeightReading(heightMeters: event.heightMeters, source: .event(event.kind))
        }
        guard forecast.hasCurve else { return nil }
        return interpolatedSampleHeight(at: instant, samples: forecast.samples)
            .map { HeightReading(heightMeters: $0, source: .interpolatedBetweenSamples) }
    }

    /// Linear interpolation between the two NOAA samples that bracket `instant`.
    /// Returns `nil` outside the sampled range or across gaps wider than
    /// `maximumInterpolationGap`.
    public static func interpolatedSampleHeight(at instant: Date, samples: [TideSample]) -> Double? {
        guard let (lower, upper) = bracketingSamples(at: instant, samples: samples) else { return nil }
        let span = upper.date.timeIntervalSince(lower.date)
        guard span > 0 else { return lower.heightMeters }
        let fraction = instant.timeIntervalSince(lower.date) / span
        return lower.heightMeters + (upper.heightMeters - lower.heightMeters) * fraction
    }

    static func bracketingSamples(at instant: Date, samples: [TideSample]) -> (TideSample, TideSample)? {
        guard let first = samples.first, let last = samples.last,
              instant >= first.date, instant <= last.date else { return nil }
        // Binary search for the last sample at or before the instant.
        var low = 0
        var high = samples.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if samples[mid].date <= instant { low = mid } else { high = mid - 1 }
        }
        let lower = samples[low]
        if lower.date == instant || low == samples.count - 1 { return (lower, lower) }
        let upper = samples[low + 1]
        guard upper.date.timeIntervalSince(lower.date) <= maximumInterpolationGap else { return nil }
        return (lower, upper)
    }

    // MARK: Illustration

    /// Maps a height into 0...1 within `range`, for the abstract waterline only.
    /// This is visual storytelling, not a shoreline position.
    public static func normalizedLevel(_ heightMeters: Double, within range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return min(max((heightMeters - range.lowerBound) / span, 0), 1)
    }

    /// Min/max predicted height over `interval`, using samples when present and
    /// events otherwise (events are the true extremes, so they bound the samples).
    public static func heightRange(in interval: DateInterval, forecast: TideForecast) -> ClosedRange<Double>? {
        var heights = events(in: interval, from: forecast.events).map(\.heightMeters)
        heights += forecast.samples.filter { interval.contains($0.date) }.map(\.heightMeters)
        guard let minimum = heights.min(), let maximum = heights.max() else { return nil }
        return minimum...maximum
    }

    // MARK: Freshness

    /// Forecasts older than this are flagged with their last-updated time.
    public static let agingThreshold: TimeInterval = 12 * 60 * 60

    public static func freshness(of forecast: TideForecast, at instant: Date) -> ForecastFreshness {
        guard nextEvent(after: instant, in: forecast.events) != nil, instant >= forecast.coverage.start else {
            return .expired(lastUpdated: forecast.fetchedAt)
        }
        if instant.timeIntervalSince(forecast.fetchedAt) > agingThreshold {
            return .aging(lastUpdated: forecast.fetchedAt)
        }
        return .current
    }
}

/// A height Little Tide is willing to display, and where it came from.
public struct HeightReading: Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        /// Exactly a NOAA high/low prediction.
        case event(TideEvent.Kind)
        /// Linearly interpolated between two adjacent NOAA interval predictions.
        case interpolatedBetweenSamples
    }

    public let heightMeters: Double
    public let source: Source
}
