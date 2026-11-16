import SwiftUI
import TideKit
import TideUI

/// The framed coast picture: the original illustration (or the user's own photo), with
/// an honest caption plate.
struct CoastPostcard: View {
    let station: TideStation
    let level: Double
    let treatment: VisualTreatment

    var body: some View {
        let region = CoastRegion(station: station)
        CoastArtView(region: region, waterLevel: level)
            .aspectRatio(3 / 2, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 2))
            .overlay {
                RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.sand.opacity(0.6), lineWidth: 0.5)
            }
            .overlay(alignment: .bottomLeading) {
                Text("Illustration · \(region.illustrationDescription)")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Palette.paper.opacity(0.88), in: .rect(cornerRadius: 2))
                    .padding(8)
                    .accessibilityHidden(true)
            }
            .accessibilityIdentifier("coastPostcard")
    }
}

struct FreshnessBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "clock.arrow.circlepath")
            .font(Typography.caption)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fog, in: .rect(cornerRadius: 4))
            .accessibilityIdentifier("freshnessBanner")
    }
}

/// Right now: direction (only when defensible) and the next predicted event.
struct NowSummaryView: View {
    let forecast: TideForecast
    let now: Date
    let format: TideFormat

    var body: some View {
        let moment = TideMoment(forecast: forecast, instant: now)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                EditorialLabel("Predicted tide · NOAA")
                if moment.trend != .unknown {
                    TrendBadge(trend: moment.trend)
                }
            }
            if let next = moment.nextEvent {
                Text(format.eventHeadline(next))
                    .font(Typography.eventTime)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel(format.eventAccessibilityLabel(next))
                Text("Next \(next.kind == .high ? "high" : "low") \(format.countdown(from: now, to: next.date)) · \(format.height(next.heightMeters)) · \(format.zoneAbbreviation(at: next.date))")
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityLabel("Next \(next.kind == .high ? "high" : "low") tide \(format.countdown(from: now, to: next.date)), station time.")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nowSummary")
    }
}

struct TrendBadge: View {
    let trend: TideTrend

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: trend == .rising ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.semibold))
            Text(trend == .rising ? "Rising" : "Falling")
                .font(Typography.label)
        }
        .foregroundStyle(Palette.seaGlassDeep)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .overlay(Capsule().strokeBorder(Palette.seaGlassDeep.opacity(0.5), lineWidth: 0.75))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend == .rising ? "Tide rising" : "Tide falling")
        .accessibilityIdentifier("trendBadge")
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
            EditorialLabel("Highs and lows")
                .padding(.bottom, 8)
            if events.isEmpty {
                Text("No predicted highs or lows on this day.")
                    .font(Typography.body).foregroundStyle(Palette.inkSoft)
            }
            ForEach(events, id: \.date) { event in
                Button { select(event) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: event.kind == .high ? "arrow.up.to.line" : "arrow.down.to.line")
                            .font(.footnote)
                            .foregroundStyle(Palette.seaGlassDeep)
                            .frame(width: 20)
                        Text(event.kind == .high ? "High" : "Low")
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 48, alignment: .leading)
                        Text(format.time(event.date))
                            .font(Typography.dataValue)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text(format.height(event.heightMeters))
                            .font(Typography.dataValue)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.vertical, 10)
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
                EditorialLabel("Predicted tide · NOAA CO-OPS")
                Text("Station \(station.id) · heights above \(forecast.datum) · times in \(format.zoneAbbreviation(at: now)) (station time)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Retrieved \(format.day(forecast.fetchedAt)), \(format.time(forecast.fetchedAt))")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 4) {
                    Text("About this prediction")
                    Image(systemName: "info.circle")
                }
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Palette.seaGlassDeep)
                .padding(.top, 4)
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
