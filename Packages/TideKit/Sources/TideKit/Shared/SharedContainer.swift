import Foundation

/// Locations shared by the app and the widget extension through the App Group.
public enum SharedContainer {
    public static let appGroupIdentifier = "group.app.littletide.shared"

    /// The App Group container, or a private Application Support folder when the
    /// entitlement is unavailable (unit tests, macOS tooling).
    public static var directory: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return url
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return fallback.appendingPathComponent("LittleTide", isDirectory: true)
    }

    public static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
    }

    public static var forecastDirectory: URL { directory.appendingPathComponent("Forecasts", isDirectory: true) }

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// The production repository used by both the app and the widget.
    public static func makeRepository() -> TideRepository {
        TideRepository(client: NOAATideClient(), cache: FileForecastCache(directory: forecastDirectory))
    }
}
