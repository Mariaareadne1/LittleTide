import Foundation

/// User choices shared with the widget. Values are versioned JSON so that a future
/// schema change can never crash an older widget process.
// UserDefaults is documented as thread-safe but not annotated Sendable.
public struct SharedSettings: @unchecked Sendable {
    enum Key {
        static let selectedStation = "selectedStation.v1"
        static let recentStations = "recentStations.v1"
        static let unit = "heightUnit"
        static let visualTreatment = "visualTreatment"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = SharedContainer.defaults) {
        self.defaults = defaults
    }

    public var selectedStation: TideStation? {
        guard let data = defaults.data(forKey: Key.selectedStation) else { return nil }
        return try? JSONDecoder().decode(TideStation.self, from: data)
    }

    public func setSelectedStation(_ station: TideStation?) {
        guard let station, let data = try? JSONEncoder().encode(station) else {
            defaults.removeObject(forKey: Key.selectedStation)
            return
        }
        defaults.set(data, forKey: Key.selectedStation)
    }

    /// Previously chosen coasts, most recent first. Missing or unreadable data is an empty list.
    public var recentStations: [TideStation] {
        guard let data = defaults.data(forKey: Key.recentStations) else { return [] }
        return (try? JSONDecoder().decode([TideStation].self, from: data)) ?? []
    }

    public func setRecentStations(_ stations: [TideStation]) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        defaults.set(data, forKey: Key.recentStations)
    }

    /// Defaults to feet for US users, metres elsewhere.
    public var unit: HeightUnit {
        if let raw = defaults.string(forKey: Key.unit), let unit = HeightUnit(rawValue: raw) { return unit }
        return Locale.current.measurementSystem == .metric ? .meters : .feet
    }

    public func setUnit(_ unit: HeightUnit) {
        defaults.set(unit.rawValue, forKey: Key.unit)
    }

    public var visualTreatment: VisualTreatment {
        defaults.string(forKey: Key.visualTreatment).flatMap(VisualTreatment.init(rawValue:)) ?? .photograph
    }

    public func setVisualTreatment(_ treatment: VisualTreatment) {
        defaults.set(treatment.rawValue, forKey: Key.visualTreatment)
    }

    public func removeAll() {
        [Key.selectedStation, Key.recentStations, Key.unit, Key.visualTreatment].forEach(defaults.removeObject(forKey:))
    }
}

/// Whether the coast is shown with a representative photograph or the original illustration.
public enum VisualTreatment: String, Codable, CaseIterable, Sendable {
    case photograph
    case illustration
}
