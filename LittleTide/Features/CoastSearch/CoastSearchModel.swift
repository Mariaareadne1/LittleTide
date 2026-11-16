import Foundation
import Observation
import TideKit

@Observable
@MainActor
final class CoastSearchModel {
    enum Phase: Equatable {
        case browsing
        case searching
        case results([TideStation])
        case noMatches(String)
    }

    var query = "" {
        didSet { scheduleSearch() }
    }
    private(set) var phase: Phase = .browsing
    private var searchTask: Task<Void, Never>?
    private let catalog: () -> StationCatalog?
    static let debounce: Duration = .milliseconds(180)

    init(catalog: @escaping () -> StationCatalog?) {
        self.catalog = catalog
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            phase = .browsing
            return
        }
        phase = .searching
        let catalog = catalog()
        searchTask = Task {
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled, let catalog else { return }
            let found = await Task.detached(priority: .userInitiated) { catalog.search(text) }.value
            guard !Task.isCancelled, text == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            phase = found.isEmpty ? .noMatches(text) : .results(found)
        }
    }
}

/// Hand-picked, real NOAA stations chosen for well-known shores and good data
/// (reference stations with 15-minute curves, plus one subordinate example).
/// IDs are checked against the bundled catalog at runtime; missing ones are dropped.
enum FeaturedCoasts {
    static let stationIDs = [
        "9410840", // Santa Monica, Municipal Pier, CA
        "9413450", // Monterey, CA
        "9447130", // Seattle, WA
        "8413320", // Bar Harbor, ME
        "8446121", // Provincetown, MA
        "8665530", // Charleston, SC
        "8724580", // Key West, FL
        "1612340", // Honolulu, HI
    ]

    static func stations(in catalog: StationCatalog?) -> [TideStation] {
        stationIDs.compactMap { catalog?.station(id: $0) }
    }
}
