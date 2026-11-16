import Foundation

/// Formatting that always uses the station's time zone and an explicit unit.
public struct TideFormat: Sendable {
    public let timeZone: TimeZone
    public let locale: Locale
    public let unit: HeightUnit

    public init(timeZone: TimeZone, unit: HeightUnit, locale: Locale = .autoupdatingCurrent) {
        self.timeZone = timeZone
        self.locale = locale
        self.unit = unit
    }

    /// e.g. "4:42 PM" (en_US) or "16:42" (en_GB), in station time.
    public func time(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// e.g. "Mon, Nov 16"
    public func day(_ date: Date) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar).weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// e.g. "PST" / "PDT", the abbreviation in force at `date`.
    public func zoneAbbreviation(at date: Date) -> String {
        timeZone.abbreviation(for: date) ?? timeZone.identifier
    }

    /// e.g. "4.1 ft", "−0.3 m"
    public func height(_ meters: Double) -> String {
        let value = unit.value(fromMeters: meters)
        let number = value.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return "\(number) \(unit.symbol)"
    }

    /// e.g. "High at 4:42 PM"
    public func eventHeadline(_ event: TideEvent) -> String {
        "\(event.kind == .high ? "High" : "Low") at \(time(event.date))"
    }

    /// e.g. "High tide at 4:42 PM, predicted height 4.1 feet."
    public func eventAccessibilityLabel(_ event: TideEvent) -> String {
        let value = unit.value(fromMeters: event.heightMeters)
        let number = value.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return "\(event.kind == .high ? "High" : "Low") tide at \(time(event.date)), predicted height \(number) \(unit.spokenName)."
    }

    /// e.g. "in 2 hr 14 min"
    public func countdown(from start: Date, to end: Date) -> String {
        let minutes = max(Int((end.timeIntervalSince(start) / 60).rounded(.down)), 0)
        if minutes < 1 { return "now" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "in \(remainder) min" }
        return remainder == 0 ? "in \(hours) hr" : "in \(hours) hr \(remainder) min"
    }

    public var calendar: Calendar { StationDay.calendar(in: timeZone) }
}
