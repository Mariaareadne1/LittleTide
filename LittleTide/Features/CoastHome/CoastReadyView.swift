import SwiftUI
import TideKit
import TideUI

struct CoastReadyView: View {
    let station: TideStation
    let forecast: TideForecast
    let refreshError: NOAAError?
    let now: Date
    let format: TideFormat
    @Binding var selection: Date?
    @Binding var dayOffset: Int
    let showSource: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timeZone: TimeZone { format.timeZone }
    private var today: DateInterval { StationDay.dayInterval(containing: now, timeZone: timeZone) }
    private var window: DateInterval {
        guard dayOffset != 0, let shifted = format.calendar.date(byAdding: .day, value: dayOffset, to: today.start.addingTimeInterval(3600)) else { return today }
        return StationDay.dayInterval(containing: shifted, timeZone: timeZone)
    }
    private var displayed: Date { selection ?? now }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoastPostcard(station: station, level: waterLevel, treatment: model.treatment)
                .padding(.top, 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: waterLevel)

            placeTitle.padding(.top, 20)

            if let banner = freshnessBanner {
                FreshnessBanner(text: banner).padding(.top, 14)
            }

            NowSummaryView(forecast: forecast, now: now, format: format)
                .padding(.top, 18)

            Hairline().padding(.vertical, 22)

            studySection

            Hairline().padding(.vertical, 22)

            DayEventsList(events: TideEngine.events(in: window, from: forecast.events), format: format, selection: selection) { event in
                selection = event.date
            }

            SourceFooter(station: station, forecast: forecast, now: now, format: format, action: showSource)
                .padding(.top, 28)
        }
    }

    private var placeTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(station.displayName.title)
                .font(Typography.placeTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Text("\(station.displayName.subtitle) · Station \(station.id)")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private var studySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayOffset == 0 ? "The tide today" : "The tide")
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                DayPager(label: format.day(window.start), canGoBack: canShift(-1), canGoForward: canShift(1)) { step in
                    shiftDay(step)
                }
            }

            SelectionReadout(forecast: forecast, instant: displayed, isNow: selection == nil, format: format)

            TideStudyView(
                forecast: forecast, window: window, now: now, format: format,
                isHapticsEnabled: model.isHapticsEnabled, selection: $selection
            )

            HStack {
                Text(forecast.hasCurve ? "Drag across the day to explore NOAA's predicted tide." : "This station publishes high and low times only. Drag to step between them.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                if selection != nil || dayOffset != 0 {
                    Button("Now") {
                        selection = nil
                        dayOffset = 0
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.ink)
                    .accessibilityHint("Returns the timeline to the current time.")
                    .accessibilityIdentifier("nowButton")
                }
            }
        }
    }

    /// Water level for the illustration, normalised to today's predicted range.
    /// Neutral when the selected instant has no published height.
    private var waterLevel: Double {
        guard let range = TideEngine.heightRange(in: window, forecast: forecast),
              let reading = TideEngine.height(at: displayed, forecast: forecast) else { return 0.5 }
        return TideEngine.normalizedLevel(reading.heightMeters, within: range)
    }

    private var freshnessBanner: String? {
        if let refreshError {
            return "\(refreshError == .noConnection ? "Offline" : "Couldn’t refresh") · showing predictions retrieved \(format.day(forecast.fetchedAt)), \(format.time(forecast.fetchedAt))"
        }
        if case let .aging(lastUpdated) = TideEngine.freshness(of: forecast, at: now) {
            return "Last updated \(format.day(lastUpdated)), \(format.time(lastUpdated))"
        }
        return nil
    }

    private func canShift(_ step: Int) -> Bool {
        let target = dayOffset + step
        guard (-1...6).contains(target),
              let probe = format.calendar.date(byAdding: .day, value: target, to: today.start.addingTimeInterval(3600)) else { return false }
        let day = StationDay.dayInterval(containing: probe, timeZone: timeZone)
        return !TideEngine.events(in: day, from: forecast.events).isEmpty
    }

    private func shiftDay(_ step: Int) {
        guard canShift(step) else { return }
        dayOffset += step
        if dayOffset == 0 {
            selection = nil
        } else {
            let events = TideEngine.events(in: window, from: forecast.events)
            selection = forecast.hasCurve ? window.start.addingTimeInterval(window.duration / 2) : events.first?.date
        }
    }
}

private struct DayPager: View {
    let label: String
    let canGoBack: Bool
    let canGoForward: Bool
    let shift: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                .disabled(!canGoBack)
                .accessibilityLabel("Previous day")
            Text(label)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.inkSoft)
                .accessibilityLabel("Showing \(label)")
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                .disabled(!canGoForward)
                .accessibilityLabel("Next day")
        }
        .foregroundStyle(Palette.ink)
    }
}

private struct SelectionReadout: View {
    let forecast: TideForecast
    let instant: Date
    let isNow: Bool
    let format: TideFormat

    var body: some View {
        let readout = TideReadout(forecast: forecast, instant: instant, isNow: isNow, format: format)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(isNow ? "Now" : readout.day)
                .font(Typography.label)
                .tracking(Typography.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(isNow ? Palette.inkSoft : Palette.rust)
            Text(readout.time)
                .font(Typography.dataValue)
                .foregroundStyle(Palette.ink)
            Text(readout.detail)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let height = readout.height {
                Text(height).font(Typography.dataValue).foregroundStyle(Palette.ink)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readout.spoken)
        .accessibilityIdentifier("selectionReadout")
    }
}
