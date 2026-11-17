import SwiftUI
import TideKit
import TideUI

struct CoastReadyView: View {
    let station: TideStation
    let forecast: TideForecast
    let refreshError: NOAAError?
    let now: Date
    let format: TideFormat
    let layout: HomeLayout
    let actions: HeroActions
    @Binding var selection: Date?
    @Binding var dayOffset: Int
    let showSource: () -> Void

    @Environment(AppModel.self) private var model

    private var timeZone: TimeZone { format.timeZone }
    private var today: DateInterval { StationDay.dayInterval(containing: now, timeZone: timeZone) }
    private var window: DateInterval {
        guard dayOffset != 0, let shifted = format.calendar.date(byAdding: .day, value: dayOffset, to: today.start.addingTimeInterval(3600)) else { return today }
        return StationDay.dayInterval(containing: shifted, timeZone: timeZone)
    }
    private var displayed: Date { selection ?? now }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoastHero(station: station, level: waterLevel, topInset: layout.topInset, width: layout.width, actions: actions)

            TideCard {
                NowSummaryView(forecast: forecast, now: now, format: format)
            }
            .padding(.top, -150)

            VStack(alignment: .leading, spacing: 0) {
                if let banner = freshnessBanner {
                    FreshnessBanner(text: banner).padding(.top, 16)
                }
                studySection.padding(.top, 30)
                Hairline().padding(.vertical, 26)
                DayEventsList(events: TideEngine.events(in: window, from: forecast.events), format: format, selection: selection) { event in
                    selection = event.date
                }
                SourceFooter(station: station, forecast: forecast, now: now, format: format, action: showSource)
                    .padding(.top, 30)
            }
            .padding(.horizontal, 20)
        }
    }

    private var studySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    heading
                    Spacer(minLength: 8)
                    pager
                }
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    pager
                }
            }

            SelectionReadout(forecast: forecast, instant: displayed, isNow: selection == nil, format: format)

            TideStudyView(
                forecast: forecast, window: window, now: now, format: format,
                isHapticsEnabled: model.isHapticsEnabled, selection: $selection
            )

            HStack(alignment: .center, spacing: 12) {
                Text(forecast.hasCurve ? "Drag across the day to explore NOAA’s predicted tide." : "This station publishes high and low times only. Drag to step between them.")
                    .typeStyle(.metadata)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if selection != nil || dayOffset != 0 {
                    Button {
                        selection = nil
                        dayOffset = 0
                    } label: {
                        Text("Now").typeStyle(.bodyEmphasis).padding(.horizontal, 18).frame(minHeight: 44)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .foregroundStyle(Palette.ink)
                    .accessibilityHint("Returns the timeline to the current time.")
                    .accessibilityIdentifier("nowButton")
                    .transition(.opacity)
                }
            }
        }
    }

    private var heading: some View {
        Text(dayOffset == 0 ? "The tide today" : "The tide")
            .typeStyle(.sectionHeading)
            .foregroundStyle(Palette.ink)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    private var pager: some View {
        DayPager(label: format.day(window.start), canGoBack: canShift(-1), canGoForward: canShift(1)) { shiftDay($0) }
            .fixedSize()
    }

    /// Water level for the illustration, normalised to the day's predicted range.
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
        HStack(spacing: 0) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 40, height: 44) }
                .disabled(!canGoBack)
                .accessibilityLabel("Previous day")
            Text(label)
                .typeStyle(.label)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .accessibilityLabel("Showing \(label)")
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 44) }
                .disabled(!canGoForward)
                .accessibilityLabel("Next day")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.ink)
        .glassSurface(Capsule(), interactive: true)
    }
}

private struct SelectionReadout: View {
    let forecast: TideForecast
    let instant: Date
    let isNow: Bool
    let format: TideFormat

    var body: some View {
        let readout = TideReadout(forecast: forecast, instant: instant, isNow: isNow, format: format)
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                lead(readout)
                Text(readout.detail).typeStyle(.label).foregroundStyle(Palette.ink).lineLimit(1)
                Spacer(minLength: 4)
                heightText(readout)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) { lead(readout); Spacer(minLength: 4); heightText(readout) }
                Text(readout.detail).typeStyle(.label).foregroundStyle(Palette.ink)
            }
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readout.spoken)
        .accessibilityIdentifier("selectionReadout")
    }

    private func lead(_ readout: TideReadout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(isNow ? "Now" : readout.day)
                .typeStyle(.regionLabel)
                .foregroundStyle(isNow ? Palette.inkSoft : Palette.rust)
                .fixedSize()
            Text(readout.time)
                .typeStyle(.data)
                .foregroundStyle(Palette.ink)
                .fixedSize()
                .contentTransition(.numericText())
        }
    }

    @ViewBuilder
    private func heightText(_ readout: TideReadout) -> some View {
        if let height = readout.height {
            Text(height).typeStyle(.data).foregroundStyle(Palette.ink).fixedSize()
        }
    }
}
