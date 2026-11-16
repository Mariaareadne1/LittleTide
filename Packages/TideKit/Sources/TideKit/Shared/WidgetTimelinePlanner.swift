import Foundation

/// Chooses the instants a widget timeline should render, from already-fetched
/// predictions. WidgetKit decides when entries actually display; these are the
/// moments at which the displayed facts change.
public enum WidgetTimelinePlanner {
    /// Spacing of entries that only move the "now" marker on the tide strip.
    public static let markerStep: TimeInterval = 30 * 60
    /// How far ahead entries are planned.
    public static let horizon: TimeInterval = 24 * 60 * 60
    /// When WidgetKit should ask for a new timeline (and possibly refetch).
    public static let reloadAfter: TimeInterval = 6 * 60 * 60

    public static func entryDates(for forecast: TideForecast?, now: Date) -> [Date] {
        guard let forecast else { return [now] }
        let end = now.addingTimeInterval(horizon)
        var dates: Set<Date> = [now]

        var marker = now.addingTimeInterval(markerStep)
        while marker < end {
            dates.insert(marker)
            marker = marker.addingTimeInterval(markerStep)
        }
        // Immediately after each event, "next" flips to the following event.
        for event in forecast.events where event.date > now && event.date < end {
            dates.insert(event.date.addingTimeInterval(1))
        }
        // The first instant with no known next event, so the widget can say so.
        if let last = forecast.lastUsefulInstant, last > now, last < end {
            dates.insert(last.addingTimeInterval(1))
        }
        return dates.sorted()
    }

    public static func reloadDate(for forecast: TideForecast?, now: Date) -> Date {
        let regular = now.addingTimeInterval(reloadAfter)
        guard let last = forecast?.lastUsefulInstant, last > now else {
            return now.addingTimeInterval(30 * 60)
        }
        return min(regular, last)
    }
}
