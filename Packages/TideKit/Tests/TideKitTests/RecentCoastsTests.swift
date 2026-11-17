import Foundation
import Testing
@testable import TideKit

@Suite("Recent coasts")
struct RecentCoastsTests {
    private func station(_ id: String) -> TideStation {
        TideStation(id: id, noaaName: "Station \(id)", state: "CA", latitude: 34, longitude: -118, kind: .reference,
                    referenceStationID: nil, timeZoneIdentifier: "America/Los_Angeles")
    }

    @Test func leavingACoastPutsItFirst() {
        let list = RecentCoasts.updated([station("B")], leaving: station("A"), for: station("C"))
        #expect(list.map(\.id) == ["A", "B"])
    }

    @Test func theNewCoastIsNeverListedAndDuplicatesCollapse() {
        let list = RecentCoasts.updated([station("C"), station("A"), station("B")], leaving: station("A"), for: station("C"))
        #expect(list.map(\.id) == ["A", "B"])
    }

    @Test func listIsBounded() {
        let earlier = ["B", "C", "D", "E"].map(station)
        let list = RecentCoasts.updated(earlier, leaving: station("A"), for: station("Z"))
        #expect(list.map(\.id) == ["A", "B", "C", "D"])
        #expect(RecentCoasts.limit == 4)
    }

    @Test func firstChoiceHasNothingToRemember() {
        #expect(RecentCoasts.updated([], leaving: nil, for: station("A")).isEmpty)
    }

    @Test func settingsStoreRecentsAndToleratePreviousVersions() throws {
        let defaults = try #require(UserDefaults(suiteName: "lt-recents-\(UUID().uuidString)"))
        let settings = SharedSettings(defaults: defaults)
        // An install from before recents existed has no key: an empty list, not a crash.
        #expect(settings.recentStations.isEmpty)
        settings.setRecentStations([station("A"), station("B")])
        #expect(settings.recentStations.map(\.id) == ["A", "B"])
        defaults.set(Data("garbage".utf8), forKey: SharedSettings.Key.recentStations)
        #expect(settings.recentStations.isEmpty)
    }
}
