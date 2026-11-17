import SwiftUI
import TideKit
import TideUI

/// Searchable list of NOAA tide-prediction stations, with featured coasts and a
/// browse-by-state fallback.
struct CoastSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search: CoastSearchModel?

    var body: some View {
        NavigationStack {
            Group {
                if let search {
                    content(search)
                } else {
                    ProgressView("Loading stations…")
                }
            }
            .navigationTitle("Choose a coast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { state in
                StateStationList(state: state, onPick: pick)
            }
        }
        .task {
            await model.loadCatalogIfNeeded()
            if search == nil { search = CoastSearchModel { [model] in model.catalog } }
        }
    }

    @ViewBuilder
    private func content(_ search: CoastSearchModel) -> some View {
        @Bindable var search = search
        List {
            switch search.phase {
            case .browsing:
                browseSections
            case .searching:
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("Searching")
            case let .results(stations):
                Section {
                    ForEach(stations) { StationRow(station: $0, onPick: pick) }
                } footer: {
                    Text("Results are NOAA tide-prediction stations — harbors, piers and inlets — not individual beaches.")
                }
            case let .noMatches(text):
                NoMatchesView(query: text)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Town, bay, state or station ID")
        .autocorrectionDisabled()
    }

    @ViewBuilder
    private var browseSections: some View {
        if let current = model.station {
            // The coast on screen, then earlier choices: switching back is one tap.
            Section {
                StationRow(station: current, isCurrent: true, onPick: pick)
                ForEach(model.recentStations) { StationRow(station: $0, onPick: pick) }
            } header: {
                SectionHeader(model.recentStations.isEmpty ? "Your coast" : "Your coasts")
            }
        }
        let shown = Set(([model.station].compactMap { $0 } + model.recentStations).map(\.id))
        let featured = FeaturedCoasts.stations(in: model.catalog).filter { !shown.contains($0.id) }
        if !featured.isEmpty {
            Section {
                ForEach(featured) { StationRow(station: $0, onPick: pick) }
            } header: {
                SectionHeader("Featured coasts")
            }
        }
        Section(header: SectionHeader("Browse by state")) {
            ForEach(statesInCatalog, id: \.self) { code in
                NavigationLink(value: code) {
                    Text(USStates.names[code] ?? code)
                }
            }
        }
    }

    private var statesInCatalog: [String] {
        let codes = Set(model.catalog?.stations.map(\.state) ?? [])
        return codes.sorted { (USStates.names[$0] ?? $0) < (USStates.names[$1] ?? $1) }
    }

    private func pick(_ station: TideStation) {
        model.select(station)
        dismiss()
    }
}

private struct StateStationList: View {
    @Environment(AppModel.self) private var model
    let state: String
    let onPick: (TideStation) -> Void

    var body: some View {
        let stations = (model.catalog?.stations ?? [])
            .filter { $0.state == state }
            .sorted { $0.displayName.title < $1.displayName.title }
        List(stations) { StationRow(station: $0, onPick: onPick) }
            .listStyle(.plain)
            .navigationTitle(USStates.names[state] ?? state)
    }
}

struct StationRow: View {
    let station: TideStation
    var isCurrent = false
    let onPick: (TideStation) -> Void

    var body: some View {
        Button { onPick(station) } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.displayName.title)
                        .typeStyle(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                    Text(station.displayName.subtitle)
                        .typeStyle(.metadata)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 12)
                if isCurrent {
                    Label("Showing", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .typeStyle(.metadata)
                        .foregroundStyle(Palette.ink)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(station.id)
                        .typeStyle(.metadata)
                        .foregroundStyle(Palette.inkSoft)
                    Text(station.kind == .reference ? "Curve" : "High/low")
                        .typeStyle(.metadata)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(station.displayName.title), \(station.displayName.subtitle)")
        .accessibilityValue("Station \(station.id). \(station.kind == .reference ? "Full tide curve" : "High and low times only").")
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isCurrent ? "The coast shown now." : "")
        .accessibilityIdentifier(isCurrent ? "currentStation-\(station.id)" : "station-\(station.id)")
    }
}

private struct NoMatchesView: View {
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No station matches “\(query)”")
                .typeStyle(.sectionHeading)
                .foregroundStyle(Palette.ink)
            Text("Little Tide uses NOAA tide-prediction stations, which are named for harbors, piers and inlets rather than beaches. Try a nearby town or bay, a state name, or browse by state.")
                .typeStyle(.body)
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}

/// Section header in ink tones (the system grey fails contrast on paper).
private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .typeStyle(.eventTitle)
            .foregroundStyle(Palette.ink)
            .textCase(nil)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}
