import Foundation

/// In-app legal copy. Kept in sync with Documentation/PRIVACY.md and SUPPORT.md.
enum LegalText {
    static let supportURL = URL(string: "https://github.com/Mariaareadne1/LittleTide/blob/main/Documentation/SUPPORT.md")!

    static let privacy = """
    Little Tide has no accounts, advertising, analytics or tracking.

    What leaves your phone: to get predictions, the app asks NOAA’s public Tides & Currents service for the station you chose (its station ID, a date range and units). NOAA receives that request and your device’s IP address, as with any website. No personal information is sent.

    What stays on your phone: your chosen coast, display preferences and saved predictions, kept in storage shared only with Little Tide’s own widgets. Clear saved predictions in Settings, or delete the app to remove everything.

    Little Tide does not use your location, contacts, photos or camera.
    """

    static let credits = """
    Tide predictions: NOAA Center for Operational Oceanographic Products and Services (CO-OPS), Tides & Currents, via its public Data and Metadata APIs. Station names, positions and types come from NOAA metadata. Little Tide is independent and not affiliated with or endorsed by NOAA.

    Times are converted from UTC to each station’s civil time zone by Little Tide.

    Illustrations, the Little Tide mark and the app icon are original works made for Little Tide.

    Typography: Apple system fonts (SF Pro and New York).
    """
}
