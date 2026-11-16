import Foundation

public enum NOAAError: Error, Equatable, Sendable {
    case noConnection
    case timedOut
    /// NOAA rate limiting (HTTP 429, or the 403 "Forbidden" its gateway returns).
    case throttled
    case server(status: Int)
    /// NOAA answered, but with an `error` message (bad station, no data for datum, …).
    case rejected(message: String)
    /// HTTP 200 with zero predictions.
    case noPredictions
    case malformedResponse
    case cancelled

    /// Errors worth retrying automatically after a pause.
    public var isTransient: Bool {
        switch self {
        case .timedOut, .throttled, .server: return true
        default: return false
        }
    }

    /// Short, user-facing explanation.
    public var userMessage: String {
        switch self {
        case .noConnection: return "You appear to be offline."
        case .timedOut: return "NOAA took too long to respond."
        case .throttled: return "NOAA is limiting requests right now. Try again in a few minutes."
        case .server: return "NOAA's prediction service is having trouble."
        case .rejected: return "NOAA could not provide predictions for this station."
        case .noPredictions: return "NOAA returned no predictions for this station."
        case .malformedResponse: return "NOAA sent a response Little Tide could not read."
        case .cancelled: return "The request was cancelled."
        }
    }
}
