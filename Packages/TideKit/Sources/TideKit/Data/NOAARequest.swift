import Foundation

/// Builds CO-OPS Data API requests for tide predictions.
/// https://api.tidesandcurrents.noaa.gov/api/prod/
public struct NOAARequest: Hashable, Sendable {
    public enum Interval: Hashable, Sendable {
        case highLow
        case minutes(Int)

        var queryValue: String {
            switch self {
            case .highLow: return "hilo"
            case let .minutes(minutes): return String(minutes)
            }
        }
    }

    public static let baseURL = URL(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter")!
    /// NOAA asks clients to identify themselves with `application`.
    public static let applicationName = "LittleTide_iOS"
    public static let defaultDatum = "MLLW"

    public let stationID: String
    public let begin: Date
    public let rangeHours: Int
    public let interval: Interval
    public let datum: String

    public init(stationID: String, begin: Date, rangeHours: Int, interval: Interval, datum: String = Self.defaultDatum) {
        self.stationID = stationID
        self.begin = begin
        self.rangeHours = rangeHours
        self.interval = interval
        self.datum = datum
    }

    public var url: URL {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "product", value: "predictions"),
            URLQueryItem(name: "application", value: Self.applicationName),
            URLQueryItem(name: "station", value: stationID),
            URLQueryItem(name: "begin_date", value: NOAATimestamp.requestString(from: begin)),
            URLQueryItem(name: "range", value: String(rangeHours)),
            URLQueryItem(name: "datum", value: datum),
            URLQueryItem(name: "units", value: "metric"),
            // Exchange absolute times; display conversion happens in the station's zone.
            URLQueryItem(name: "time_zone", value: "gmt"),
            URLQueryItem(name: "interval", value: interval.queryValue),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components.url!
    }

    public var coverage: DateInterval {
        DateInterval(start: begin, duration: TimeInterval(rangeHours) * 3600)
    }
}

/// NOAA timestamps in `time_zone=gmt` responses: "yyyy-MM-dd HH:mm", UTC.
enum NOAATimestamp {
    static func parse(_ string: String) -> Date? {
        let parts = string.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" }).compactMap { Int($0) }
        guard parts.count == 5 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = parts[3]
        components.minute = parts[4]
        guard (1...12).contains(parts[1]), (1...31).contains(parts[2]),
              (0...23).contains(parts[3]), (0...59).contains(parts[4]) else { return nil }
        return utcCalendar.date(from: components)
    }

    static func requestString(from date: Date) -> String {
        let c = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d%02d%02d %02d:%02d", c.year!, c.month!, c.day!, c.hour!, c.minute!)
    }

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
