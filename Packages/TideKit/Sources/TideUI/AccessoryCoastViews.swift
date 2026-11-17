import SwiftUI
import TideKit

/// Lock Screen (accessory) widget faces. The system renders these monochrome or tinted,
/// so they use system styles, SF Symbols and text only, never the painting.
public enum AccessoryFace: Sendable {
    case inline, circular, rectangular
}

public struct AccessoryCoastView: View {
    let content: CoastWidgetContent
    let face: AccessoryFace

    public init(content: CoastWidgetContent, face: AccessoryFace) {
        self.content = content
        self.face = face
    }

    public var body: some View {
        switch face {
        case .inline: inline
        case .circular: circular
        case .rectangular: rectangular
        }
    }

    // MARK: Inline — one line above the clock

    @ViewBuilder
    private var inline: some View {
        switch content.state {
        case .unconfigured:
            Label("Choose a coast", systemImage: "water.waves")
        case .unavailable:
            Label("Open Little Tide", systemImage: "water.waves")
        case let .ready(ready):
            Label("\(ready.nextKindWord) \(ready.nextTime)", systemImage: AccessoryText.symbol(for: ready))
                .accessibilityLabel(ready.accessibilityLabel)
        }
    }

    // MARK: Circular — kind, time, and where the water sits in the day's range

    @ViewBuilder
    private var circular: some View {
        switch content.state {
        case .unconfigured, .unavailable:
            Image(systemName: "water.waves")
                .font(.title2)
                .accessibilityLabel(content.station == nil ? "Little Tide: choose a coast" : "Little Tide: open the app for new predictions")
        case let .ready(ready):
            if let level = ready.waterLevel {
                // Gauge = predicted level within the next 24 h range; only when NOAA publishes a height now.
                Gauge(value: level) {
                    Image(systemName: AccessoryText.symbol(for: ready))
                } currentValueLabel: {
                    Text(AccessoryText.shortTime(ready.nextTime)).minimumScaleFactor(0.6)
                }
                .gaugeStyle(.accessoryCircular)
                .accessibilityLabel(ready.accessibilityLabel)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: AccessoryText.symbol(for: ready)).font(.caption.weight(.bold))
                    Text(AccessoryText.shortTime(ready.nextTime)).font(.system(.headline, design: .rounded)).minimumScaleFactor(0.6)
                    Text(ready.nextKindWord.uppercased()).font(.system(size: 9, weight: .semibold))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ready.accessibilityLabel)
            }
        }
    }

    // MARK: Rectangular — place, next event, direction

    @ViewBuilder
    private var rectangular: some View {
        switch content.state {
        case .unconfigured:
            VStack(alignment: .leading, spacing: 2) {
                Text("Little Tide").font(.headline).widgetAccentableIfAvailable()
                Text("Choose a coast in the app").font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .unavailable(station, _):
            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayName.title).font(.headline).lineLimit(1).widgetAccentableIfAvailable()
                Text("Open Little Tide for new predictions").font(.caption).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .ready(ready):
            VStack(alignment: .leading, spacing: 1) {
                Text(ready.station.displayName.title)
                    .font(.headline).lineLimit(1)
                    .widgetAccentableIfAvailable()
                Label(ready.headline, systemImage: AccessoryText.symbol(for: ready))
                    .font(.body.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(ready.agingNote ?? AccessoryText.detail(for: ready))
                    .font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready.accessibilityLabel)
        }
    }
}
