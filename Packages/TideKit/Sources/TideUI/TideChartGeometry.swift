import CoreGraphics
import Foundation
import TideKit

/// Maps instants and heights into a drawing rect. Shared by the app's tide study and
/// the medium widget's rhythm strip so both place marks identically.
public struct TideChartGeometry: Sendable {
    public let window: DateInterval
    public let heightRange: ClosedRange<Double>
    public let rect: CGRect

    /// Pads the data range so extremes are not drawn on the frame edge.
    public init(window: DateInterval, dataRange: ClosedRange<Double>, rect: CGRect, padding: Double = 0.12) {
        let span = max(dataRange.upperBound - dataRange.lowerBound, 0.1)
        self.window = window
        heightRange = (dataRange.lowerBound - span * padding)...(dataRange.upperBound + span * padding)
        self.rect = rect
    }

    /// Unclamped: instants outside the window map outside the rect, so callers clip
    /// rather than piling points onto the edges.
    public func x(for date: Date) -> CGFloat {
        let fraction = date.timeIntervalSince(window.start) / max(window.duration, 1)
        return rect.minX + CGFloat(fraction) * rect.width
    }

    public func y(for heightMeters: Double) -> CGFloat {
        let span = heightRange.upperBound - heightRange.lowerBound
        let fraction = (heightMeters - heightRange.lowerBound) / max(span, 0.0001)
        return rect.maxY - CGFloat(min(max(fraction, 0), 1)) * rect.height
    }

    public func date(forX x: CGFloat) -> Date {
        let fraction = Double(min(max((x - rect.minX) / max(rect.width, 1), 0), 1))
        return window.start.addingTimeInterval(window.duration * fraction)
    }

    public func point(_ sample: TideSample) -> CGPoint {
        CGPoint(x: x(for: sample.date), y: y(for: sample.heightMeters))
    }

    public func point(_ event: TideEvent) -> CGPoint {
        CGPoint(x: x(for: event.date), y: y(for: event.heightMeters))
    }

    /// Curve through NOAA samples, broken wherever samples are further apart than the
    /// engine allows interpolation (so gaps stay visibly empty).
    public func curvePath(samples: [TideSample]) -> CGPath {
        let path = CGMutablePath()
        var previous: TideSample?
        for sample in samples where sample.date >= window.start.addingTimeInterval(-3600) && sample.date <= window.end.addingTimeInterval(3600) {
            let p = point(sample)
            if let prev = previous, sample.date.timeIntervalSince(prev.date) <= TideEngine.maximumInterpolationGap {
                path.addLine(to: p)
            } else {
                path.move(to: p)
            }
            previous = sample
        }
        return path
    }

    /// Closed area under the curve down to the rect's bottom edge, per contiguous run.
    public func areaPath(samples: [TideSample]) -> CGPath {
        let path = CGMutablePath()
        var run: [CGPoint] = []
        var previous: TideSample?
        func flush() {
            guard let first = run.first, let last = run.last, run.count > 1 else { run = []; return }
            path.move(to: CGPoint(x: first.x, y: rect.maxY))
            run.forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.closeSubpath()
            run = []
        }
        for sample in samples where sample.date >= window.start.addingTimeInterval(-3600) && sample.date <= window.end.addingTimeInterval(3600) {
            if let prev = previous, sample.date.timeIntervalSince(prev.date) > TideEngine.maximumInterpolationGap { flush() }
            run.append(point(sample))
            previous = sample
        }
        flush()
        return path
    }
}
