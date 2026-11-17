import Foundation

/// Text for the Lock Screen widget faces, kept pure so it can be tested without UI.
public enum AccessoryText {
    public static func symbol(for ready: CoastWidgetContent.Ready) -> String {
        switch ready.trend {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .unknown: return ready.next.kind == .high ? "arrow.up.to.line" : "arrow.down.to.line"
        }
    }

    /// "1:04 PM" → "1:04" for the circular face (the kind is shown by the symbol).
    /// Times without a trailing meridiem (24-hour locales) are returned unchanged.
    public static func shortTime(_ time: String) -> String {
        let trimmed = time.replacingOccurrences(of: "\u{202F}", with: " ")
        guard let space = trimmed.lastIndex(of: " "),
              trimmed[trimmed.index(after: space)...].allSatisfy(\.isLetter) else { return time }
        return String(trimmed[..<space])
    }

    /// e.g. "Rising · 4.1 ft"; "Predicted" when NOAA's data cannot say which way.
    public static func detail(for ready: CoastWidgetContent.Ready) -> String {
        let direction: String
        switch ready.trend {
        case .rising: direction = "Rising"
        case .falling: direction = "Falling"
        case .unknown: direction = "Predicted"
        }
        return "\(direction) · \(ready.nextHeight)"
    }
}
