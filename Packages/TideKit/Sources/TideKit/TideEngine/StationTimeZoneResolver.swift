import Foundation

/// Derives an IANA civil time zone for a NOAA station.
///
/// NOAA metadata only carries `timezonecorr`, a standard-time offset, and NOAA's own
/// `lst_ldt` output does not follow civil time everywhere (for example Alaska stations
/// tagged −10/−11 are published without daylight saving, and some Florida stations
/// carry an offset that contradicts their county). Little Tide always displays the
/// civil time a person standing at the station would see on their phone, so it
/// resolves the zone from the state and, where a state spans zones, the longitude.
public enum StationTimeZoneResolver {
    /// Florida's coastal Eastern/Central boundary sits west of Port St. Joe (≈ −85.3°).
    static let floridaCentralWestOfLongitude = -85.4
    /// The Aleutians west of 169.5° W keep Hawaii–Aleutian time. The Pribilof Islands
    /// are also west of that meridian but further north, and use Alaska time.
    static let alaskaAleutianWestOfLongitude = -169.5
    static let alaskaAleutianSouthOfLatitude = 55.5

    static let eastern: Set<String> = [
        "ME", "NH", "MA", "RI", "CT", "NY", "NJ", "PA", "DE", "MD", "DC", "VA", "NC", "SC", "GA",
    ]
    static let central: Set<String> = ["AL", "MS", "LA", "TX"]
    static let pacific: Set<String> = ["CA", "OR", "WA"]

    /// States and territories Little Tide V1 supports.
    public static let supportedStates: Set<String> = eastern
        .union(central).union(pacific).union(["FL", "AK", "HI", "PR", "VI", "GU"])

    /// Returns `nil` for stations outside V1's supported US geography.
    public static func timeZoneIdentifier(state: String, latitude: Double, longitude: Double) -> String? {
        switch state {
        case _ where eastern.contains(state): return "America/New_York"
        case _ where central.contains(state): return "America/Chicago"
        case _ where pacific.contains(state): return "America/Los_Angeles"
        case "FL":
            return longitude < floridaCentralWestOfLongitude ? "America/Chicago" : "America/New_York"
        case "AK":
            // East longitudes (Attu, Near Islands) are also Aleutian.
            let isWestOfMeridian = longitude < alaskaAleutianWestOfLongitude || longitude > 0
            let isAleutian = isWestOfMeridian && latitude < alaskaAleutianSouthOfLatitude
            return isAleutian ? "America/Adak" : "America/Anchorage"
        case "HI": return "Pacific/Honolulu"
        case "PR", "VI": return "America/Puerto_Rico"
        case "GU": return "Pacific/Guam"
        default: return nil
        }
    }
}
