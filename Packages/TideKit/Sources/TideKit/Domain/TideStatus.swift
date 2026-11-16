import Foundation

/// Direction of the predicted tide at an instant. `unknown` is a first-class answer:
/// Little Tide hides the claim rather than guess.
public enum TideTrend: String, Codable, Hashable, Sendable {
    case rising
    case falling
    case unknown
}

/// How trustworthy a cached forecast is at a given moment.
public enum ForecastFreshness: Hashable, Sendable {
    /// Retrieved recently and covers the requested instant.
    case current
    /// Still covers the instant, but was retrieved a while ago (e.g. offline).
    case aging(lastUpdated: Date)
    /// No longer covers the instant (no known next event). Must not be shown as current.
    case expired(lastUpdated: Date)

    public var isUsable: Bool {
        if case .expired = self { return false }
        return true
    }
}

public enum HeightUnit: String, Codable, CaseIterable, Sendable {
    case feet
    case meters

    public static let metersPerFoot = 0.3048

    public func value(fromMeters meters: Double) -> Double {
        self == .feet ? meters / Self.metersPerFoot : meters
    }

    public var symbol: String { self == .feet ? "ft" : "m" }
    public var spokenName: String { self == .feet ? "feet" : "meters" }
}
