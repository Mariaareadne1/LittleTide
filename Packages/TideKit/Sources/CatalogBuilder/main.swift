import Foundation
import TideKit

// Builds TideKit/Resources/stations.json from NOAA CO-OPS metadata.
//
//   swift run catalog-builder [path/to/noaa-stations.json]
//
// Without an argument it downloads
// https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions
//
// Rules (documented in Documentation/DATA.md):
// - keep stations whose NOAA state is a supported US state/territory;
// - stations NOAA lists without a state get one from a state abbreviation in their
//   name ("Point Adams, Oreg."), else from a supported-state station within 20 km;
//   Canadian names and NOAA's Canadian 82xxxxx IDs are excluded;
// - each station's civil IANA zone comes from StationTimeZoneResolver.

struct NOAAStation: Decodable {
    let id: String
    let name: String
    let state: String?
    let lat: Double
    let lng: Double
    let type: String
    let reference_id: String?
}

struct NOAAList: Decodable { let stations: [NOAAStation] }

/// Abbreviations NOAA uses at the end of older station names.
let nameSuffixStates: [(String, String)] = [
    ("wash.", "WA"), ("oreg.", "OR"), ("calif.", "CA"), ("md.", "MD"), ("va.", "VA"), ("del.", "DE"),
    ("n.j.", "NJ"), ("pa.", "PA"), ("d.c.", "DC"), ("n.y.", "NY"), ("conn.", "CT"), ("r.i.", "RI"),
    ("mass.", "MA"), ("me.", "ME"), ("n.h.", "NH"), ("n.c.", "NC"), ("s.c.", "SC"), ("ga.", "GA"),
    ("fla.", "FL"), ("ala.", "AL"), ("miss.", "MS"), ("la.", "LA"), ("tex.", "TX"), ("guam", "GU"),
]

func stateFromName(_ name: String) -> String? {
    let lowered = name.lowercased().trimmingCharacters(in: .whitespaces)
    return nameSuffixStates.first { lowered.hasSuffix(", " + $0.0) || lowered.hasSuffix(" " + $0.0) }?.1
}

let sourceURL = URL(string: "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions")!
let arguments = CommandLine.arguments
let data: Data = try {
    if arguments.count > 1 { return try Data(contentsOf: URL(fileURLWithPath: arguments[1])) }
    return try Data(contentsOf: sourceURL)
}()
let raw = try JSONDecoder().decode(NOAAList.self, from: data).stations

func distanceKm(_ a: NOAAStation, _ b: NOAAStation) -> Double {
    let r = 6371.0
    let dLat = (b.lat - a.lat) * .pi / 180
    let dLng = (b.lng - a.lng) * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
    return 2 * r * asin(min(1, sqrt(h)))
}

let supported = StationTimeZoneResolver.supportedStates
let stated = raw.filter { supported.contains($0.state ?? "") }
var inferred = 0
var stations: [TideStation] = []
for station in raw {
    var state = station.state ?? ""
    if state.isEmpty {
        let lowered = station.name.lowercased()
        let isCanadian = station.id.hasPrefix("82") || lowered.contains("b.c.")
            || lowered.contains("canada") || lowered.contains("british columbia")
        if let named = stateFromName(station.name) {
            state = named
        } else if !isCanadian {
            let nearest = stated.min { distanceKm(station, $0) < distanceKm(station, $1) }
            if let nearest, distanceKm(station, nearest) <= 20 { state = nearest.state ?? "" }
        }
        if !state.isEmpty { inferred += 1 }
    }
    guard supported.contains(state),
          let kind = TideStation.Kind(rawValue: station.type),
          let zone = StationTimeZoneResolver.timeZoneIdentifier(state: state, latitude: station.lat, longitude: station.lng),
          TimeZone(identifier: zone) != nil
    else { continue }
    let reference = station.reference_id.flatMap { $0.isEmpty || $0 == station.id ? nil : $0 }
    stations.append(TideStation(
        id: station.id, noaaName: station.name.trimmingCharacters(in: .whitespaces), state: state,
        latitude: station.lat, longitude: station.lng, kind: kind,
        referenceStationID: reference, timeZoneIdentifier: zone
    ))
}
stations.sort { $0.id < $1.id }

let output = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("TideKit/Resources/stations.json")
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.sortedKeys]
let file = StationCatalog.File(generatedAt: Date(), source: sourceURL.absoluteString, stations: stations)
try encoder.encode(file).write(to: output, options: .atomic)
let references = stations.filter { $0.kind == .reference }.count
print("NOAA stations: \(raw.count); kept \(stations.count) (\(references) reference, \(stations.count - references) subordinate); state inferred for \(inferred)")
print("Wrote \(output.path)")
