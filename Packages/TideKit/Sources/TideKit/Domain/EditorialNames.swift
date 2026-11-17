import Foundation

/// Short, geographically accurate place labels for well-known stations. The official
/// NOAA name and ID are always kept in station details; these only shape the headline.
/// Every entry was checked against the station's NOAA name and coordinates.
public enum EditorialNames {
    public struct Label: Hashable, Sendable {
        public let place: String
        public let region: String
    }

    static let labels: [String: Label] = [
        "8447435": Label(place: "Chatham", region: "Cape Cod, MA"),          // Chatham Harbor, Aunt Lydias Cove
        "8447505": Label(place: "Stage Harbor", region: "Chatham, Cape Cod, MA"),
        "8446121": Label(place: "Provincetown", region: "Cape Cod, MA"),
        "8446613": Label(place: "Wellfleet", region: "Cape Cod, MA"),
        "8413320": Label(place: "Bar Harbor", region: "Mount Desert Island, ME"),
        "9415020": Label(place: "Point Reyes", region: "Marin County, CA"),
        "9413450": Label(place: "Monterey", region: "Monterey Bay, CA"),
        "9410840": Label(place: "Santa Monica", region: "Municipal Pier, CA"),
        "9410230": Label(place: "La Jolla", region: "San Diego, CA"),       // Scripps Institution Wharf
        "1612340": Label(place: "Honolulu", region: "Oʻahu, HI"),
        "8724580": Label(place: "Key West", region: "Florida Keys, FL"),
    ]

    public static func label(for stationID: String) -> Label? { labels[stationID] }
}

extension TideStation {
    /// Headline place and region, using an editorial label when one is verified.
    public var headline: (place: String, region: String) {
        if let label = EditorialNames.label(for: id) { return (label.place, label.region) }
        return (displayName.title, displayName.subtitle)
    }
}
