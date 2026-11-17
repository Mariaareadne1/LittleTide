import SwiftUI
import TideKit
import TideUI

struct FreshnessBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "clock.arrow.circlepath")
            .typeStyle(.label)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fog, in: .rect(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("freshnessBanner")
    }
}

/// Right now: direction (only when defensible) and the next predicted event.
/// Rendered inside the glass `TideCard`.
struct NowSummaryView: View {
    let forecast: TideForecast
    let now: Date
    let format: TideFormat

    var body: some View {
        let moment = TideMoment(forecast: forecast, instant: now)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if moment.trend != .unknown {
                    TrendBadge(trend: moment.trend)
                } else {
                    Text("Predicted tide").typeStyle(.label).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 8)
                Text("NOAA").typeStyle(.regionLabel).foregroundStyle(Palette.ink)
            }
            if let next = moment.nextEvent {
                Text(format.eventHeadline(next))
                    .typeStyle(.heroTideTime)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
                    .accessibilityLabel(format.eventAccessibilityLabel(next))
                Text("Next \(next.kind == .high ? "high" : "low") \(format.countdown(from: now, to: next.date)) · \(format.height(next.heightMeters)) · \(format.zoneAbbreviation(at: next.date))")
                    .typeStyle(.body)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .contentTransition(.numericText())
                    .accessibilityLabel("Next \(next.kind == .high ? "high" : "low") tide \(format.countdown(from: now, to: next.date)), station time.")
            }
        }
        // One element, read in order: direction, next event, countdown.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nowSummary")
    }
}

struct TrendBadge: View {
    let trend: TideTrend

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: trend == .rising ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.seaGlassDeep)
            Text(trend == .rising ? "Rising tide" : "Falling tide")
                .typeStyle(.label)
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend == .rising ? "Tide rising" : "Tide falling")
    }
}

/// The day's predicted highs and lows as a quiet table. Tapping one selects it.
struct DayEventsList: View {
    let events: [TideEvent]
    let format: TideFormat
    let selection: Date?
    let select: (TideEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Highs and lows")
                .typeStyle(.regionLabel)
                .foregroundStyle(Palette.inkSoft)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            if events.isEmpty {
                Text("No predicted highs or lows on this day.")
                    .typeStyle(.body).foregroundStyle(Palette.inkSoft)
            }
            ForEach(events, id: \.date) { event in
                Button { select(event) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: event.kind == .high ? "arrow.up.to.line" : "arrow.down.to.line")
                            .font(.footnote)
                            .foregroundStyle(Palette.seaGlassDeep)
                            .frame(width: 20)
                        Text(event.kind == .high ? "High tide" : "Low tide")
                            .typeStyle(.eventTitle)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Text(format.time(event.date))
                            .typeStyle(.data)
                            .foregroundStyle(Palette.ink)
                        Text(format.height(event.heightMeters))
                            .typeStyle(.data)
                            .foregroundStyle(Palette.inkSoft)
                            .frame(minWidth: 62, alignment: .trailing)
                    }
                    .padding(.vertical, 12)
                    .contentShape(.rect)
                    .background(alignment: .leading) {
                        if selection == event.date {
                            Rectangle().fill(Palette.rust).frame(width: 2).offset(x: -10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(format.eventAccessibilityLabel(event))
                .accessibilityHint("Shows this prediction on the timeline.")
                if event != events.last { Hairline() }
            }
        }
    }
}

/// Provenance, always visible: source, station, datum, time zone and retrieval time.
struct SourceFooter: View {
    let station: TideStation
    let forecast: TideForecast
    let now: Date
    let format: TideFormat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Predicted tide · NOAA CO-OPS")
                    .typeStyle(.regionLabel)
                    .foregroundStyle(Palette.inkSoft)
                Text("Station \(station.id) · heights above \(forecast.datum) · times in \(format.zoneAbbreviation(at: now)) (station time)")
                    .typeStyle(.metadata)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Retrieved \(format.day(forecast.fetchedAt)), \(format.time(forecast.fetchedAt))")
                    .typeStyle(.metadata)
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 4) {
                    Text("About this prediction")
                    Image(systemName: "info.circle")
                }
                .typeStyle(.label)
                .foregroundStyle(Palette.seaGlassDeep)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the data source, datum and limitations.")
        .accessibilityIdentifier("sourceFooter")
    }
}
