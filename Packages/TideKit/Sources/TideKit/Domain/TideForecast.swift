import Foundation

/// Everything Little Tide knows about one station's predicted tide, with provenance.
public struct TideForecast: Codable, Hashable, Sendable {
    public enum CurveAvailability: Codable, Hashable, Sendable {
        /// NOAA returned interval predictions; `samples` is non-empty.
        case available(intervalMinutes: Int)
        /// NOAA did not provide interval predictions; only high/low events exist.
        case unavailable(reason: String)
    }

    public let stationID: String
    /// Vertical datum the heights are referenced to, e.g. "MLLW".
    public let datum: String
    /// When the predictions were retrieved from NOAA.
    public let fetchedAt: Date
    /// The time range NOAA was asked to cover. Values outside it are never shown.
    public let coverage: DateInterval
    /// High/low events, sorted by time.
    public let events: [TideEvent]
    /// Interval predictions, sorted by time. Empty when `curve` is `.unavailable`.
    public let samples: [TideSample]
    public let curve: CurveAvailability

    public init(
        stationID: String,
        datum: String,
        fetchedAt: Date,
        coverage: DateInterval,
        events: [TideEvent],
        samples: [TideSample],
        curve: CurveAvailability
    ) {
        self.stationID = stationID
        self.datum = datum
        self.fetchedAt = fetchedAt
        self.coverage = coverage
        self.events = events.sorted { $0.date < $1.date }
        self.samples = samples.sorted { $0.date < $1.date }
        self.curve = curve
    }

    public var hasCurve: Bool {
        if case .available = curve { return !samples.isEmpty }
        return false
    }

    /// The last instant for which this forecast can still answer "what is next?":
    /// the final predicted event (after it, there is no known next event).
    public var lastUsefulInstant: Date? { events.last?.date }
}
