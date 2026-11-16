import Foundation

/// Calendar arithmetic in a station's own time zone, never the device's.
public enum StationDay {
    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// The station-local calendar day containing `instant`. Its length is 23, 24 or
    /// 25 hours depending on daylight-saving transitions.
    public static func dayInterval(containing instant: Date, timeZone: TimeZone) -> DateInterval {
        let calendar = calendar(in: timeZone)
        // `dateInterval(of:for:)` handles DST days correctly.
        if let interval = calendar.dateInterval(of: .day, for: instant) { return interval }
        let start = calendar.startOfDay(for: instant)
        return DateInterval(start: start, duration: 24 * 60 * 60)
    }

    /// Whether two instants fall on the same station-local calendar day.
    public static func isSameDay(_ first: Date, _ second: Date, timeZone: TimeZone) -> Bool {
        calendar(in: timeZone).isDate(first, inSameDayAs: second)
    }
}
