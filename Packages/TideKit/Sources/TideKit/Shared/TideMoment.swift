import Foundation

/// Everything the UI needs to describe the tide at one instant, derived only from
/// NOAA predictions. Shared by the app and the widget.
public struct TideMoment: Hashable, Sendable {
    public let instant: Date
    public let previousEvent: TideEvent?
    public let nextEvent: TideEvent?
    /// The event the instant sits on, if any.
    public let currentEvent: TideEvent?
    public let trend: TideTrend
    public let height: HeightReading?
    public let freshness: ForecastFreshness

    public init(forecast: TideForecast, instant: Date) {
        self.instant = instant
        previousEvent = TideEngine.previousEvent(atOrBefore: instant, in: forecast.events)
        nextEvent = TideEngine.nextEvent(after: instant, in: forecast.events)
        currentEvent = TideEngine.event(at: instant, in: forecast.events)
        trend = TideEngine.trend(at: instant, forecast: forecast)
        height = TideEngine.height(at: instant, forecast: forecast)
        freshness = TideEngine.freshness(of: forecast, at: instant)
    }
}
