import SwiftUI
import TideKit
import TideUI
import WidgetKit

@main
struct LittleTideWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoastWidget()
    }
}

struct CoastWidget: Widget {
    static let kind = "LittleTideCoast"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CoastTimelineProvider()) { entry in
            CoastWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Little Tide")
        .description("The next predicted high or low at your coast, from NOAA.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CoastEntry: TimelineEntry {
    let date: Date
    let content: CoastWidgetContent
    let isPlaceholder: Bool
}

struct CoastTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoastEntry {
        // Synchronous, no I/O; rendered redacted, so no tide values are implied.
        CoastEntry(date: .now, content: CoastWidgetContent(date: .now, station: nil, forecast: nil, unit: .feet), isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (CoastEntry) -> Void) {
        let now = Date()
        let settings = SharedSettings()
        let station = settings.selectedStation
        let forecast = station.flatMap { FileForecastCache(directory: SharedContainer.forecastDirectory).load(stationID: $0.id) }
        completion(CoastEntry(date: now, content: CoastWidgetContent(date: now, station: station, forecast: forecast, unit: settings.unit), isPlaceholder: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoastEntry>) -> Void) {
        // WidgetKit's completion handler may be called from any thread but is not
        // annotated Sendable; box it to hand it to the async task.
        let reply = UncheckedSendableBox(completion)
        Task {
            reply.value(await Self.makeTimeline(now: Date()))
        }
    }

    static func makeTimeline(now: Date) async -> Timeline<CoastEntry> {
        let settings = SharedSettings()
        guard let station = settings.selectedStation else {
            let entry = CoastEntry(date: now, content: CoastWidgetContent(date: now, station: nil, forecast: nil, unit: settings.unit), isPlaceholder: false)
            return Timeline(entries: [entry], policy: .never) // the app reloads on selection
        }
        let repository = SharedContainer.makeRepository()
        var forecast = await repository.cachedForecast(for: station.id)
        if await repository.needsRefresh(forecast, manual: false) {
            // Respectful: the repository enforces minimum intervals and dedupes.
            if let result = try? await repository.forecast(for: station) { forecast = result.forecast }
        }
        let unit = settings.unit
        let entries = WidgetTimelinePlanner.entryDates(for: forecast, now: now).map { date in
            CoastEntry(date: date, content: CoastWidgetContent(date: date, station: station, forecast: forecast, unit: unit), isPlaceholder: false)
        }
        return Timeline(entries: entries, policy: .after(WidgetTimelinePlanner.reloadDate(for: forecast, now: now)))
    }
}

struct CoastWidgetEntryView: View {
    let entry: CoastEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let rendering: CoastCardRendering = renderingMode == .fullColor ? .fullColor : .monochrome
        Group {
            switch family {
            case .systemMedium:
                MediumCoastCard(content: entry.content, rendering: rendering)
            default:
                SmallCoastCard(content: entry.content, rendering: rendering)
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(for: .widget) { Palette.paper }
        .widgetURL(url)
    }

    private var url: URL? {
        switch entry.content.state {
        case .unconfigured: return URL(string: "littletide://open")
        case let .unavailable(station, _): return URL(string: "littletide://station/\(station.id)")
        case let .ready(ready): return URL(string: "littletide://station/\(ready.station.id)")
        }
    }
}

private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
