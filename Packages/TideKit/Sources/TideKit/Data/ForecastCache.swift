import Foundation

public protocol ForecastCaching: Sendable {
    func load(stationID: String) -> TideForecast?
    func save(_ forecast: TideForecast) throws
    func removeAll() throws
}

/// Stores one JSON file per station in a (usually App Group) directory.
/// The payload is versioned; unreadable or older-schema files are discarded, never
/// partially trusted.
public struct FileForecastCache: ForecastCaching {
    public static let schemaVersion = 1

    struct Envelope: Codable {
        let schemaVersion: Int
        let forecast: TideForecast
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func load(stationID: String) -> TideForecast? {
        let url = fileURL(for: stationID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let envelope = try? Self.decoder.decode(Envelope.self, from: data),
              envelope.schemaVersion == Self.schemaVersion,
              envelope.forecast.stationID == stationID
        else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return envelope.forecast
    }

    public func save(_ forecast: TideForecast) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(Envelope(schemaVersion: Self.schemaVersion, forecast: forecast))
        try data.write(to: fileURL(for: forecast.stationID), options: .atomic)
    }

    public func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    func fileURL(for stationID: String) -> URL {
        // Station IDs are alphanumeric (e.g. "9410840", "TPT2705"); strip anything else.
        let safe = stationID.filter { $0.isLetter || $0.isNumber }
        return directory.appendingPathComponent("forecast-\(safe).json")
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}
