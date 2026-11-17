import SwiftUI
import TideKit
import TideUI

/// Offline or ageing predictions, said plainly inside the tide card.
struct FreshnessLine: View {
    let text: String

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .typeStyle(.label)
        .foregroundStyle(Palette.onArt)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Palette.onArt.opacity(0.22)).frame(height: 1) }
        .accessibilityElement(children: .combine)
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    direction(moment)
                    Spacer(minLength: 8)
                    sourceTag
                }
                VStack(alignment: .leading, spacing: 4) {
                    direction(moment)
                    sourceTag
                }
            }
            if let next = moment.nextEvent {
                Text(format.eventHeadline(next))
                    .typeStyle(.heroTideTime)
                    .foregroundStyle(Palette.onArt)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                    .accessibilityLabel(format.eventAccessibilityLabel(next))
                Text("Next \(next.kind == .high ? "high" : "low") \(format.countdown(from: now, to: next.date)) · \(format.height(next.heightMeters)) · \(format.zoneAbbreviation(at: next.date))")
                    .typeStyle(.body)
                    .monospacedDigit()
                    .foregroundStyle(Palette.onArtSoft)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Next \(next.kind == .high ? "high" : "low") tide \(format.countdown(from: now, to: next.date)), station time.")
            }
        }
        // One element, read in order: direction, next event, countdown.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nowSummary")
    }

    @ViewBuilder
    private func direction(_ moment: TideMoment) -> some View {
        if moment.trend != .unknown {
            TrendBadge(trend: moment.trend)
        } else {
            Text("Predicted tide").typeStyle(.label).foregroundStyle(Palette.onArt)
        }
    }

    private var sourceTag: some View {
        Text("Predicted · NOAA").typeStyle(.regionLabel).foregroundStyle(Palette.onArtSoft)
    }
}

struct TrendBadge: View {
    let trend: TideTrend

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: trend == .rising ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.onArt)
            Text(trend == .rising ? "Rising tide" : "Falling tide")
                .typeStyle(.label)
                .foregroundStyle(Palette.onArt)
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
                .foregroundStyle(Palette.onArtSoft)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            if events.isEmpty {
                Text("No predicted highs or lows on this day.")
                    .typeStyle(.body).foregroundStyle(Palette.onArtSoft)
            }
            ForEach(events, id: \.date) { event in
                Button { select(event) } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            icon(event)
                            title(event)
                            Spacer(minLength: 8)
                            time(event)
                            height(event).frame(minWidth: 62, alignment: .trailing)
                        }
                        // Accessibility sizes: title on one line, time and height on the next.
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) { icon(event); title(event) }
                            HStack {
                                time(event)
                                Spacer(minLength: 8)
                                height(event)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(.rect)
                    .background(alignment: .leading) {
                        if selection == event.date {
                            Rectangle().fill(Palette.coral).frame(width: 2).offset(x: -10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(format.eventAccessibilityLabel(event))
                .accessibilityHint("Shows this prediction on the timeline.")
                if event != events.last { Rectangle().fill(Palette.onArt.opacity(0.18)).frame(height: 0.5) }
            }
        }
    }

    private func icon(_ event: TideEvent) -> some View {
        Image(systemName: event.kind == .high ? "arrow.up.to.line" : "arrow.down.to.line")
            .font(.footnote)
            .foregroundStyle(Palette.onArtSoft)
            .frame(width: 20)
    }

    private func title(_ event: TideEvent) -> some View {
        Text(event.kind == .high ? "High tide" : "Low tide").typeStyle(.eventTitle).foregroundStyle(Palette.onArt)
    }

    private func time(_ event: TideEvent) -> some View {
        Text(format.time(event.date)).typeStyle(.data).foregroundStyle(Palette.onArt).lineLimit(1)
    }

    private func height(_ event: TideEvent) -> some View {
        Text(format.height(event.heightMeters)).typeStyle(.data).foregroundStyle(Palette.onArtSoft).lineLimit(1)
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
                    .foregroundStyle(Palette.onArtSoft)
                Text("Station \(station.id) · heights above \(forecast.datum) · times in \(format.zoneAbbreviation(at: now)) (station time)")
                    .typeStyle(.metadata)
                    .foregroundStyle(Palette.onArtSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Retrieved \(format.day(forecast.fetchedAt)), \(format.time(forecast.fetchedAt))")
                    .typeStyle(.metadata)
                    .foregroundStyle(Palette.onArtSoft)
                HStack(spacing: 4) {
                    Text("About this prediction")
                    Image(systemName: "info.circle")
                }
                .typeStyle(.label)
                .foregroundStyle(Palette.onArt)
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
