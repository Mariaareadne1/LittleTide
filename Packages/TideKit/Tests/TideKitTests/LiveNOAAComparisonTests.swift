import Foundation
import Testing
@testable import TideKit

/// Compares Little Tide's pipeline (GMT + metric from NOAA, converted to the station's
/// civil zone and to feet) against NOAA's own published local-time, English-unit
/// predictions for the same stations and dates.
///
///     LITTLETIDE_LIVE=1 swift test --filter LiveNOAAComparison
@Suite("Live NOAA comparison", .enabled(if: ProcessInfo.processInfo.environment["LITTLETIDE_LIVE"] == "1"), .serialized)
struct LiveNOAAComparisonTests {
    static let stationIDs = [
        "9410840", // Santa Monica, CA — reference, Pacific
        "8413320", // Bar Harbor, ME — reference, Eastern
        "1612340", // Honolulu, HI — reference, no DST
        "8724580", // Key West, FL — reference, Gulf/Atlantic
        "8510502", // Montauk Harbor entrance, NY — subordinate
    ]

    @Test(arguments: stationIDs)
    func matchesNOAAPublishedPredictions(stationID: String) async throws {
        let catalog = try StationCatalog.bundled()
        let station = try #require(catalog.station(id: stationID))
        let zone = try #require(station.timeZone)
        try await Task.sleep(for: .seconds(2)) // be polite to NOAA

        let now = Date()
        let ours = try await NOAATideClient().fetchForecast(for: station, now: now)
        try await Task.sleep(for: .seconds(2))

        let day = StationDay.dayInterval(containing: now, timeZone: zone)
        let calendar = StationDay.calendar(in: zone)
        let ymd = { (d: Date) -> String in
            let c = calendar.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d%02d%02d", c.year!, c.month!, c.day!)
        }
        var components = URLComponents(url: NOAARequest.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "product", value: "predictions"), .init(name: "application", value: NOAARequest.applicationName),
            .init(name: "station", value: stationID), .init(name: "begin_date", value: ymd(day.start)),
            .init(name: "end_date", value: ymd(day.start)), .init(name: "datum", value: "MLLW"),
            .init(name: "units", value: "english"), .init(name: "time_zone", value: "lst_ldt"),
            .init(name: "interval", value: "hilo"), .init(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        struct Published: Decodable { struct Row: Decodable { let t, v, type: String }; let predictions: [Row] }
        let published = try JSONDecoder().decode(Published.self, from: data).predictions

        let format = TideFormat(timeZone: zone, unit: .feet, locale: Locale(identifier: "en_US_POSIX"))
        let ourDay = TideEngine.events(in: day, from: ours.events)
        #expect(ourDay.count == published.count, "\(stationID): \(ourDay.count) vs NOAA \(published.count)")

        var lines = ["\(stationID) \(station.noaaName) [\(station.kind.rawValue)] \(zone.identifier) \(ymd(day.start))"]
        for (mine, theirs) in zip(ourDay, published) {
            var local = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: mine.date)
            local.second = nil
            let mineText = String(format: "%04d-%02d-%02d %02d:%02d", local.year!, local.month!, local.day!, local.hour!, local.minute!)
            let feet = HeightUnit.feet.value(fromMeters: mine.heightMeters)
            let theirFeet = try #require(Double(theirs.v))
            #expect(mineText == theirs.t, "\(stationID) time \(mineText) vs \(theirs.t)")
            #expect(mine.kind.rawValue == theirs.type)
            #expect(abs(feet - theirFeet) < 0.01, "\(stationID) height \(feet) vs \(theirFeet)")
            lines.append("  ours \(mineText) \(mine.kind.rawValue) \(String(format: "%.3f", feet)) ft (\(format.time(mine.date)))  |  NOAA \(theirs.t) \(theirs.type) \(theirs.v) ft")
        }
        let report = lines.joined(separator: "\n")
        print(report)
        if let path = ProcessInfo.processInfo.environment["LITTLETIDE_LIVE_REPORT"] {
            let handle = FileHandle(forWritingAtPath: path) ?? {
                FileManager.default.createFile(atPath: path, contents: nil)
                return FileHandle(forWritingAtPath: path)!
            }()
            handle.seekToEndOfFile()
            handle.write(Data((report + "\n\n").utf8))
            try handle.close()
        }
    }
}
