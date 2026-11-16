import Foundation

/// Broad coastal character used to pick an illustration. Deliberately coarse: the art is
/// representative of a kind of coast, never a depiction of the station itself.
public enum CoastRegion: String, Codable, CaseIterable, Sendable {
    case pacificHeadlands
    case northAtlantic
    case southAtlanticMarsh
    case gulfShore
    case tropicalIsland
    case northernFjord

    public init(station: TideStation) {
        switch station.state {
        case "CA", "OR", "WA": self = .pacificHeadlands
        case "ME", "NH", "MA", "RI", "CT", "NY", "NJ": self = .northAtlantic
        case "PA", "DE", "MD", "DC", "VA", "NC", "SC", "GA": self = .southAtlanticMarsh
        case "AL", "MS", "LA", "TX": self = .gulfShore
        case "HI", "PR", "VI", "GU": self = .tropicalIsland
        case "AK": self = .northernFjord
        case "FL":
            if station.latitude < 25.35 { self = .tropicalIsland } // the Keys
            else if station.longitude < -81.6 || station.latitude > 29.6 && station.longitude < -82.5 { self = .gulfShore }
            else { self = .southAtlanticMarsh }
        default: self = .northAtlantic
        }
    }

    /// Plain-language description used in the illustration's caption and VoiceOver label.
    public var illustrationDescription: String {
        switch self {
        case .pacificHeadlands: return "Pacific headlands and sea stacks"
        case .northAtlantic: return "North Atlantic dunes and granite"
        case .southAtlanticMarsh: return "Low-country marsh and barrier beach"
        case .gulfShore: return "Gulf shore with old pilings"
        case .tropicalIsland: return "Volcanic island shore"
        case .northernFjord: return "Northern fjord and mountains"
        }
    }
}
