import SwiftUI
import TideKit
import TideUI

/// "The tide today": NOAA's predicted curve (or, for high/low-only stations, the
/// predicted events alone) across one station-local day, with a draggable selection.
struct TideStudyView: View {
    let forecast: TideForecast
    let window: DateInterval
    let now: Date
    let format: TideFormat
    let isHapticsEnabled: Bool
    @Binding var selection: Date?

    @State private var hapticTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let chartHeight: CGFloat = 168
    static let accessibilityStep: TimeInterval = 15 * 60

    private var dayEvents: [TideEvent] { TideEngine.events(in: window, from: forecast.events) }
    private var dataRange: ClosedRange<Double> {
        TideEngine.heightRange(in: window, forecast: forecast) ?? (0...1)
    }
    private var displayed: Date { selection ?? now }

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(x: 0, y: 18, width: proxy.size.width, height: proxy.size.height - 40)
            let geometry = TideChartGeometry(window: window, dataRange: dataRange, rect: rect)
            Canvas { context, _ in
                draw(in: &context, geometry: geometry)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in select(geometry.date(forX: value.location.x)) }
            )
        }
        .frame(height: Self.chartHeight)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: hapticTick) { _, _ in isHapticsEnabled }
        .accessibilityElement()
        .accessibilityLabel("Tide study, \(format.day(window.start))")
        .accessibilityValue(accessibilityReadout)
        .accessibilityHint(forecast.hasCurve ? "Swipe up or down to move through the day in 15 minute steps." : "Swipe up or down to move between predicted highs and lows.")
        .accessibilityAdjustableAction { direction in
            adjust(direction == .increment ? 1 : -1)
        }
        .accessibilityIdentifier("tideStudy")
    }

    // MARK: Selection

    private func select(_ date: Date) {
        let target: Date
        if forecast.hasCurve {
            target = date
        } else {
            // Without interval data only the predicted events are real; snap to them.
            guard let nearest = dayEvents.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else { return }
            target = nearest.date
        }
        let previous = displayed
        if target == previous { return }
        let crossed = dayEvents.contains { event in
            (previous < event.date && event.date <= target) || (target <= event.date && event.date < previous)
        }
        if crossed { hapticTick += 1 }
        selection = target
    }

    private func adjust(_ step: Int) {
        if forecast.hasCurve {
            let next = displayed.addingTimeInterval(Double(step) * Self.accessibilityStep)
            selection = min(max(next, window.start), window.end.addingTimeInterval(-60))
        } else {
            let candidates = step > 0 ? dayEvents.filter { $0.date > displayed } : dayEvents.filter { $0.date < displayed }.reversed()
            if let event = candidates.first { selection = event.date }
        }
    }

    private var accessibilityReadout: String {
        TideReadout(forecast: forecast, instant: displayed, isNow: selection == nil, format: format).spoken
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, geometry: TideChartGeometry) {
        let rect = geometry.rect
        drawGrid(in: &context, geometry: geometry)

        var plot = context
        plot.clip(to: Path(CGRect(x: rect.minX, y: 0, width: rect.width, height: rect.maxY + 1)))
        if forecast.hasCurve {
            let area = Path(geometry.areaPath(samples: forecast.samples))
            plot.fill(area, with: .linearGradient(
                Gradient(colors: [Palette.seaGlass.opacity(0.32), Palette.seaGlass.opacity(0.06)]),
                startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
            ))
            plot.stroke(Path(geometry.curvePath(samples: forecast.samples)), with: .color(Palette.seaGlassDeep), lineWidth: 1.5)
        } else {
            // Event stems only: nothing is drawn between predictions NOAA does not publish.
            for event in dayEvents {
                let p = geometry.point(event)
                var stem = Path()
                stem.move(to: CGPoint(x: p.x, y: rect.maxY))
                stem.addLine(to: p)
                context.stroke(stem, with: .color(Palette.seaGlass), lineWidth: 2)
            }
        }

        for event in dayEvents {
            let p = geometry.point(event)
            let dot = Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7))
            context.fill(dot, with: .color(Palette.paper))
            context.stroke(dot, with: .color(Palette.seaGlassDeep), lineWidth: 1.5)
            let label = Text(event.kind == .high ? "H \(format.time(event.date))" : "L \(format.time(event.date))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.inkSoft)
            let resolved = context.resolve(label)
            let labelSize = resolved.measure(in: CGSize(width: 200, height: 40))
            let gap: CGFloat = 6 + labelSize.height / 2
            // Highs label above, lows below — unless there is no room, then flip.
            let roomBelow = rect.maxY - p.y >= gap + labelSize.height / 2
            let roomAbove = p.y - rect.minY + 18 >= gap + labelSize.height / 2
            let above = event.kind == .high ? roomAbove : !roomBelow
            let x = min(max(p.x, rect.minX + labelSize.width / 2), rect.maxX - labelSize.width / 2)
            let y = above ? p.y - gap : p.y + gap
            let backing = CGRect(x: x - labelSize.width / 2 - 3, y: y - labelSize.height / 2 - 1, width: labelSize.width + 6, height: labelSize.height + 2)
            context.fill(Path(roundedRect: backing, cornerRadius: 3), with: .color(Palette.paper.opacity(0.85)))
            context.draw(resolved, at: CGPoint(x: x, y: y))
        }

        if window.contains(now) {
            let x = geometry.x(for: now)
            var line = Path()
            line.move(to: CGPoint(x: x, y: rect.minY))
            line.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(line, with: .color(Palette.inkSoft.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }

        if let selection, window.contains(selection) {
            let x = geometry.x(for: selection)
            var line = Path()
            line.move(to: CGPoint(x: x, y: rect.minY - 6))
            line.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(line, with: .color(Palette.rust), lineWidth: 1.5)
            if let reading = TideEngine.height(at: selection, forecast: forecast) {
                let y = geometry.y(for: reading.heightMeters)
                let knob = Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                context.fill(knob, with: .color(Palette.rust))
                context.stroke(knob, with: .color(Palette.paper), lineWidth: 1.5)
            }
        }
    }

    private func drawGrid(in context: inout GraphicsContext, geometry: TideChartGeometry) {
        let rect = geometry.rect
        var baseline = Path()
        baseline.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        baseline.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        context.stroke(baseline, with: .color(Palette.sand), lineWidth: 1)

        // Datum (0) line, when the day's range reaches it.
        if geometry.heightRange.contains(0) {
            let y = geometry.y(for: 0)
            var datum = Path()
            datum.move(to: CGPoint(x: rect.minX, y: y))
            datum.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.stroke(datum, with: .color(Palette.sand), style: StrokeStyle(lineWidth: 0.75, dash: [1, 3]))
            context.draw(
                Text("0 \(format.unit.symbol) \(forecast.datum)").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.inkSoft),
                at: CGPoint(x: rect.minX + 2, y: y - 7), anchor: .leading
            )
        }

        // Hour ticks every 3 h in station time, labelled at 6-hour marks.
        let calendar = format.calendar
        var tick = window.start
        while tick < window.end {
            let hour = calendar.component(.hour, from: tick)
            let x = geometry.x(for: tick)
            var mark = Path()
            mark.move(to: CGPoint(x: x, y: rect.maxY))
            mark.addLine(to: CGPoint(x: x, y: rect.maxY + (hour % 6 == 0 ? 5 : 3)))
            context.stroke(mark, with: .color(Palette.inkSoft.opacity(0.6)), lineWidth: 0.75)
            if hour % 6 == 0 {
                let label = Text(hourLabel(tick)).font(.system(size: 10).monospacedDigit()).foregroundStyle(Palette.inkSoft)
                let isFirst = x <= rect.minX + 1
                context.draw(label, at: CGPoint(x: x, y: rect.maxY + 14), anchor: isFirst ? .leading : .center)
            }
            guard let next = calendar.date(byAdding: .hour, value: 3, to: calendar.dateInterval(of: .hour, for: tick)?.start ?? tick) else { break }
            tick = next
        }
    }

    private func hourLabel(_ date: Date) -> String {
        var style = Date.FormatStyle(locale: format.locale, calendar: format.calendar).hour(.defaultDigits(amPM: .abbreviated))
        style.timeZone = format.timeZone
        return date.formatted(style)
    }
}
