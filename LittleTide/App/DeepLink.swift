import Foundation

/// `littletide://station/<NOAA station id>`, used by widgets.
enum DeepLink: Equatable {
    case station(String)

    static let scheme = "littletide"

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == "station" else { return nil }
        let id = url.pathComponents.dropFirst().first ?? ""
        guard !id.isEmpty, id.count <= 12, id.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        self = .station(id)
    }

    var url: URL {
        switch self {
        case let .station(id): return URL(string: "\(Self.scheme)://station/\(id)")!
        }
    }
}
