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
    @State private var detailPanels: [GlassPanel] = []

    private var timeZone: TimeZone { format.timeZone }
    private var today: DateInterval { StationDay.dayInterval(containing: now, timeZone: timeZone) }
    private var window: DateInterval {
        guard dayOffset != 0, let shifted = format.calendar.date(byAdding: .day, value: dayOffset, to: today.start.addingTimeInterval(3600)) else { return today }
        return StationDay.dayInterval(containing: shifted, timeZone: timeZone)
    }
    private var displayed: Date { selection ?? now }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoastHero(station: station, level: waterLevel, layout: layout, actions: actions) {
                TideCard {
                    NowSummaryView(forecast: forecast, now: now, format: format)
                    // Staleness belongs on the first screen, next to the claim it qualifies.
                    if let freshness {
                        FreshnessLine(text: freshness).padding(.top, 12)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                studySection.padding(.top, 28)
                DayEventsList(events: TideEngine.events(in: window, from: forecast.events), format: format, selection: selection) { event in
                    selection = event.date
                }
                .padding(.horizontal, 18).padding(.vertical, 8)
                .oceanGlass(cornerRadius: 24)
                .padding(.top, 24)
                SourceFooter(station: station, forecast: forecast, now: now, format: format, action: showSource)
                    .padding(18)
                    .oceanGlass(cornerRadius: 24)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
            .background {
                // Deep water beneath the details, so their glass refracts painted water too.
                if let scene = PaintedScene(region: CoastRegion(station: station)) {
                    // Extends past the content so over-scroll and the home indicator area
                    // show painted water rather than a flat band.
                    PaintedCoastView(scene: scene, level: 0.5, mode: .underwater, panels: detailPanels,
                                     isAnimating: layout.areDetailsVisible)
                        .padding(.bottom, -400)
                }
            }
            .glassStage("detailsGlass") { detailPanels = $0 }
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

            // The same painted shore, cropped to the waterline, follows the scrubbed time so the
            // tide visibly moves while the hero is scrolled away.
            if let scene = PaintedScene(region: CoastRegion(station: station)) {
                CoastWindow(scene: scene, level: waterLevel, hasHeight: TideEngine.height(at: displayed, forecast: forecast) != nil,
                            isAnimating: layout.areDetailsVisible)
            }

            TideStudyView(
                forecast: forecast, window: window, now: now, format: format,
                isHapticsEnabled: model.isHapticsEnabled, selection: $selection,
                fill: PaintedScene(region: CoastRegion(station: station))?.chartFill
            )
            // Axis and event labels stop growing at xLarge so they never collide; the readout
            // above carries the same facts at full size, and VoiceOver reads the chart's value.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)

            HStack(alignment: .center, spacing: 12) {
                Text(forecast.hasCurve ? "Drag across the day to explore NOAA’s predicted tide." : "This station publishes high and low times only. Drag to step between them.")
                    .typeStyle(.metadata)
                    .foregroundStyle(Palette.onArtSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if selection != nil || dayOffset != 0 {
                    Button {
                        selection = nil
                        dayOffset = 0
                    } label: {
                        Text("Now").typeStyle(.bodyEmphasis).padding(.horizontal, 18).frame(minHeight: 44)
                    }
                    .buttonStyle(OceanGlassButtonStyle())
                    .foregroundStyle(Palette.onArt)
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
            .foregroundStyle(Palette.onArt)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    private var pager: some View {
        DayPager(label: format.day(window.start), canGoBack: canShift(-1), canGoForward: canShift(1)) { shiftDay($0) }
            .fixedSize()
    }

    /// Water level for the hero illustration at the displayed instant (now, or the scrubbed
    /// time), normalised to the displayed day's predicted range so paging days never clips.
    /// Neutral when the instant has no published height.
    private var waterLevel: Double {
        guard let range = TideEngine.heightRange(in: window, forecast: forecast),
              let reading = TideEngine.height(at: displayed, forecast: forecast) else { return 0.5 }
        return TideEngine.normalizedLevel(reading.heightMeters, within: range)
    }

    private var freshness: String? {
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

/// A wide crop of the painted coast at the selected instant's predicted level.
private struct CoastWindow: View {
    let scene: PaintedScene
    let level: Double
    let hasHeight: Bool
    let isAnimating: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PaintedCoastView(scene: scene, level: level, isAnimating: isAnimating)
                .accessibilityHidden(true)
            Text(hasHeight ? "Illustrative waterline" : "No published height at this time")
                .typeStyle(.metadata)
                .foregroundStyle(Palette.onArt)
                .lineLimit(2)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Palette.oceanDeep.opacity(0.78), in: .capsule)
                .padding(10)
        }
        .frame(height: 112)
        .clipShape(.rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.onArt.opacity(0.28), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration of a representative shoreline at the selected time's predicted level. Not a live view.")
        .accessibilityValue(spokenLevel)
        .accessibilityIdentifier("coastWindow")
    }

    /// Where the water sits within the day's predicted range, in words.
    private var spokenLevel: String {
        guard hasHeight else { return "No published height" }
        switch level {
        case ..<0.34: return "Water near the day's low"
        case 0.67...: return "Water near the day's high"
        default: return "Water midway through the day's range"
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
                .foregroundStyle(Palette.onArt)
                .contentTransition(.numericText())
                .accessibilityLabel("Showing \(label)")
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 44) }
                .disabled(!canGoForward)
                .accessibilityLabel("Next day")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.onArt)
        .liquidGlass(cornerRadius: 999, kind: .button)
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
                Text(readout.detail).typeStyle(.label).foregroundStyle(Palette.onArtSoft).lineLimit(1)
                Spacer(minLength: 4)
                heightText(readout)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) { lead(readout); Spacer(minLength: 4); heightText(readout) }
                Text(readout.detail).typeStyle(.label).foregroundStyle(Palette.onArtSoft)
            }
            // Accessibility sizes: one fact per line, nothing fixed-width.
            VStack(alignment: .leading, spacing: 4) {
                Text(isNow ? "Now" : readout.day).typeStyle(.regionLabel).foregroundStyle(isNow ? Palette.onArtSoft : Palette.coral)
                Text(readout.time).typeStyle(.data).foregroundStyle(Palette.onArt)
                if let height = readout.height { Text(height).typeStyle(.data).foregroundStyle(Palette.onArt) }
                Text(readout.detail).typeStyle(.label).foregroundStyle(Palette.onArtSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(isNow ? Palette.onArtSoft : Palette.coral)
                .fixedSize()
            Text(readout.time)
                .typeStyle(.data)
                .foregroundStyle(Palette.onArt)
                .fixedSize()
                .contentTransition(.numericText())
        }
    }

    @ViewBuilder
    private func heightText(_ readout: TideReadout) -> some View {
        if let height = readout.height {
            Text(height).typeStyle(.data).foregroundStyle(Palette.onArt).fixedSize()
        }
    }
}
