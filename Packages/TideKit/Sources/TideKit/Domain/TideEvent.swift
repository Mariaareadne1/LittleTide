import Foundation

/// A predicted high or low water event, exactly as NOAA publishes it (`interval=hilo`).
public struct TideEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case high = "H"
        case low = "L"

        public var opposite: Kind { self == .high ? .low : .high }
    }

    public let date: Date
    /// Predicted height in metres above the forecast's datum (may be negative).
    public let heightMeters: Double
    public let kind: Kind

    public init(date: Date, heightMeters: Double, kind: Kind) {
        self.date = date
        self.heightMeters = heightMeters
        self.kind = kind
    }
}

/// One regularly spaced NOAA interval prediction (e.g. every 15 minutes).
/// Only stations NOAA supports for interval predictions have these.
public struct TideSample: Codable, Hashable, Sendable {
    public let date: Date
    public let heightMeters: Double

    public init(date: Date, heightMeters: Double) {
        self.date = date
        self.heightMeters = heightMeters
    }
}
