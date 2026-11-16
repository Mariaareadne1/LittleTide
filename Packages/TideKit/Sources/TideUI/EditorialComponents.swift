import SwiftUI

/// Small uppercase editorial label, e.g. "PREDICTED TIDE · NOAA".
public struct EditorialLabel: View {
    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(Typography.label)
            .tracking(Typography.labelTracking)
            .textCase(.uppercase)
            .foregroundStyle(Palette.inkSoft)
    }
}

/// A hairline rule in the sand colour.
public struct Hairline: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Palette.sand)
            .frame(height: 1 / 2)
            .accessibilityHidden(true)
    }
}

/// The Little Tide mark: a horizon line with a single tide-line arc beneath it.
public struct TideMark: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var horizon = Path()
            horizon.move(to: CGPoint(x: w * 0.12, y: h * 0.42))
            horizon.addLine(to: CGPoint(x: w * 0.88, y: h * 0.42))
            var tide = Path()
            tide.move(to: CGPoint(x: w * 0.12, y: h * 0.66))
            tide.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.66),
                control1: CGPoint(x: w * 0.38, y: h * 0.50),
                control2: CGPoint(x: w * 0.62, y: h * 0.82)
            )
            let line = max(1, w / 14)
            context.stroke(horizon, with: .color(Palette.ink), style: StrokeStyle(lineWidth: line, lineCap: .round))
            context.stroke(tide, with: .color(Palette.seaGlassDeep), style: StrokeStyle(lineWidth: line, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}
