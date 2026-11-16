import SwiftUI
import TideKit
import TideUI

/// Where the numbers come from, what they mean, and what they are not.
struct SourceInfoSheet: View {
    let station: TideStation
    let forecast: TideForecast?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section("Station") {
                    LabeledContent("Name", value: station.noaaName)
                    LabeledContent("NOAA station ID", value: station.id)
                    LabeledContent("Type", value: station.kind == .reference ? "Reference (harmonic)" : "Subordinate")
                    if let reference = station.referenceStationID, station.kind == .subordinate {
                        LabeledContent("Based on station", value: referenceName(reference))
                    }
                    LabeledContent("Location", value: String(format: "%.4f°, %.4f°", station.latitude, station.longitude))
                    LabeledContent("Station time zone", value: station.timeZoneIdentifier)
                    Link("View on NOAA Tides & Currents", destination: URL(string: "https://tidesandcurrents.noaa.gov/noaatidepredictions.html?id=\(station.id)")!)
                }
                Section("This prediction") {
                    LabeledContent("Source", value: "NOAA CO-OPS tide predictions")
                    if let forecast {
                        LabeledContent("Datum", value: forecast.datum)
                        let format = TideFormat(timeZone: station.timeZone ?? .gmt, unit: model.unit)
                        LabeledContent("Retrieved", value: "\(format.day(forecast.fetchedAt)), \(format.time(forecast.fetchedAt)) \(format.zoneAbbreviation(at: forecast.fetchedAt))")
                        LabeledContent("Curve", value: forecast.hasCurve ? "15-minute predictions" : "High and low times only")
                    }
                }
                Section("What the numbers mean") {
                    Text("Heights are measured from Mean Lower Low Water (MLLW): the average of each day’s lower low water at this station over a 19-year period. They are not water depth. Negative values mean the water is predicted to fall below that average.")
                    if station.kind == .subordinate {
                        Text("This is a subordinate station. NOAA derives its highs and lows from a nearby reference station and does not publish a continuous curve, so Little Tide shows only those predicted times and heights.")
                    }
                    Text("Times are shown in the station’s local time, whatever time zone your phone is in.")
                }
                Section("Limitations") {
                    Text("These are astronomical predictions. Wind, air pressure, river flow and storms can make actual water levels differ, sometimes by a lot. Local beach shape is not included.")
                    Text("Little Tide is not a navigation, boating, flood or safety tool. Check official forecasts and local conditions before going near the water.")
                    Text("Little Tide is an independent app and is not affiliated with or endorsed by NOAA.")
                }
                Section("Illustration") {
                    Text("The coast picture is an original illustration representative of \(CoastRegion(station: station).illustrationDescription.lowercased()). It is not a photograph of this station or a live view. Its waterline moves within the day’s predicted range for visual storytelling only.")
                }
            }
            .navigationTitle("About this prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func referenceName(_ id: String) -> String {
        if let name = model.catalog?.station(id: id)?.displayName.title { return "\(name) (\(id))" }
        return id
    }
}
