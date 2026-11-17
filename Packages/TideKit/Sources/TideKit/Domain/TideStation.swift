import Foundation

/// A NOAA CO-OPS tide-prediction station, as published in the CO-OPS Metadata API
/// (`type=tidepredictions`). Little Tide never invents stations: every value here is
/// either copied from NOAA metadata or derived from it by `StationTimeZoneResolver`.
public struct TideStation: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// Harmonic reference station. NOAA can usually produce interval (curve) predictions.
        case reference = "R"
        /// Subordinate station. Predictions are offsets from a reference station; NOAA
        /// generally publishes high/low events only.
        case subordinate = "S"
    }

    public let id: String
    /// Station name exactly as NOAA publishes it.
    public let noaaName: String
    /// Two-letter US state or territory code.
    public let state: String
    public let latitude: Double
    public let longitude: Double
    public let kind: Kind
    public let referenceStationID: String?
    /// IANA identifier for the station's civil time zone.
    public let timeZoneIdentifier: String

    public init(
        id: String,
        noaaName: String,
        state: String,
        latitude: Double,
        longitude: Double,
        kind: Kind,
        referenceStationID: String?,
        timeZoneIdentifier: String
    ) {
        self.id = id
        self.noaaName = noaaName
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
        self.referenceStationID = referenceStationID
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// The station's civil time zone, or `nil` if the identifier is not recognised by
    /// this OS. Callers must not silently substitute the device time zone.
    public var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

    public var displayName: StationDisplayName { StationDisplayName(noaaName: noaaName, state: state) }
}

/// Human-friendly presentation of NOAA's often ALL-CAPS station names.
public struct StationDisplayName: Hashable, Sendable {
    /// e.g. "Monterey"
    public let title: String
    /// e.g. "Monterey Bay · CA", or "Scripps Institution Wharf · CA"
    public let subtitle: String

    public init(noaaName: String, state: String) {
        let pretty = Self.prettify(noaaName)
        let parts = pretty.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        var title = parts.first.flatMap { $0.isEmpty ? nil : $0 } ?? pretty
        var details: [String] = []
        // A trailing parenthetical is a sub-location ("La Jolla (Scripps Institution Wharf)");
        // move it to the subtitle so the headline stays a place name. Nothing is invented.
        if title.hasSuffix(")"), let open = title.lastIndex(of: "("), open > title.startIndex {
            let inner = title[title.index(after: open)..<title.index(before: title.endIndex)].trimmingCharacters(in: .whitespaces)
            let head = title[..<open].trimmingCharacters(in: .whitespaces)
            if !head.isEmpty, !inner.isEmpty {
                title = head
                details.append(inner)
            }
        }
        if parts.count > 1, !parts[1].isEmpty { details.append(parts[1]) }
        details.append(state)
        self.title = title
        subtitle = details.joined(separator: " · ")
    }

    /// Title-cases NOAA's ALL-CAPS place names ("SAN DIEGO (Broadway)" → "San Diego
    /// (Broadway)"). Only the leading run of all-caps words is changed, so acronyms in
    /// names NOAA already wrote in mixed case ("(USCG S-1 Platform)") are preserved.
    /// Tokens with periods or digits ("RR.", "U.S.") are always kept.
    static func prettify(_ name: String) -> String {
        let minorWords: Set<String> = ["of", "the", "and", "at", "de", "del", "la"]
        var isLeadingRun = true
        var isFirst = true
        let words = name.split(separator: " ", omittingEmptySubsequences: false).map { raw -> String in
            defer { isFirst = false }
            let word = String(raw)
            let letters = word.filter(\.isLetter)
            let isAllCaps = letters.count >= 2 && letters == letters.uppercased()
            if !letters.isEmpty, !isAllCaps { isLeadingRun = false }
            guard isLeadingRun, isAllCaps, !word.contains("."), !word.contains(where: \.isNumber) else { return word }
            let lower = word.lowercased()
            if !isFirst, minorWords.contains(lower) { return lower }
            return lower.capitalizedPreservingPunctuation
        }
        return words.joined(separator: " ")
    }
}

private extension String {
    /// Capitalizes letters after spaces, parentheses, hyphens and slashes.
    var capitalizedPreservingPunctuation: String {
        var result = ""
        var capitalizeNext = true
        for character in self {
            if capitalizeNext, character.isLetter {
                result.append(contentsOf: character.uppercased())
                capitalizeNext = false
            } else {
                result.append(character)
                if !character.isLetter, character != "'" { capitalizeNext = true }
            }
        }
        return result
    }
}
