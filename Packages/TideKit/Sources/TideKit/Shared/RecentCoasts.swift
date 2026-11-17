import Foundation

/// The coasts someone chose before, most recent first, so switching back is one tap.
public enum RecentCoasts {
    public static let limit = 4

    /// The list after moving from `previous` to `current`: `previous` goes first, `current`
    /// is never listed (it is already on screen), duplicates collapse, and the list is bounded.
    public static func updated(_ recents: [TideStation], leaving previous: TideStation?, for current: TideStation) -> [TideStation] {
        let candidates = (previous.map { [$0] } ?? []) + recents
        var seen: Set<String> = [current.id]
        let unique = candidates.filter { seen.insert($0.id).inserted }
        return Array(unique.prefix(limit))
    }
}
