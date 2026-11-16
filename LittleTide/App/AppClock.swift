import Foundation

/// Injectable clock. Production uses the system time; screenshot and UI tests pass a
/// fixed instant so date-boundary states are reproducible.
struct AppClock: Sendable {
    let now: @Sendable () -> Date

    static let system = AppClock(now: { Date() })

    static func fixed(_ date: Date) -> AppClock {
        AppClock(now: { date })
    }
}
