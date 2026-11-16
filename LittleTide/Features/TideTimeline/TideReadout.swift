import Foundation
import TideKit

/// Words for the selected instant: what time it is at the station, and what NOAA
/// predicts there — never more than the data supports.
struct TideReadout {
    let time: String
    let day: String
    let height: String?
    let detail: String
    let spoken: String

    init(forecast: TideForecast, instant: Date, isNow: Bool, format: TideFormat) {
        let moment = TideMoment(forecast: forecast, instant: instant)
        time = format.time(instant)
        day = format.day(instant)
        height = moment.height.map { format.height($0.heightMeters) }

        let trendWord: String? = switch moment.trend {
        case .rising: "Rising"
        case .falling: "Falling"
        case .unknown: nil
        }
        if let event = moment.currentEvent {
            detail = event.kind == .high ? "High tide" : "Low tide"
        } else if let trendWord {
            detail = trendWord
        } else {
            detail = forecast.hasCurve ? "Predicted" : "Between predicted highs and lows"
        }

        let lead = isNow ? "Now, \(time)" : "\(time), \(day)"
        var parts = [lead, detail]
        if let reading = moment.height {
            let value = format.unit.value(fromMeters: reading.heightMeters)
                .formatted(.number.precision(.fractionLength(1)).locale(format.locale))
            parts.append("predicted height \(value) \(format.unit.spokenName) above \(forecast.datum)")
        }
        spoken = parts.joined(separator: ", ") + "."
    }
}
