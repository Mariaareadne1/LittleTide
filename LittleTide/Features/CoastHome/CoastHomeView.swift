import SwiftUI
import TideKit
import TideUI

/// The main view: one coast, its predicted tide now, and today's tide to explore.
struct CoastHomeView: View {
    let station: TideStation
    @Environment(AppModel.self) private var model
    @State private var selection: Date?
    @State private var dayOffset = 0
    @State private var isChoosingCoast = false
    @State private var isShowingSettings = false
    @State private var isShowingSource = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let now = model.clock.now()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    content(now: now)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .refreshable { await model.refreshAndWait() }
        }
        .background(Palette.paper.ignoresSafeArea())
        .overlay(alignment: .top) { StatusBarBacking() }
        .onChange(of: model.stationGeneration) { _, _ in
            selection = nil
            dayOffset = 0
        }
        .sheet(isPresented: $isChoosingCoast) { CoastSearchView() }
        .sheet(isPresented: $isShowingSettings) { SettingsView() }
        .sheet(isPresented: $isShowingSource) {
            SourceInfoSheet(station: station, forecast: model.forecastState.forecast)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            TideMark().frame(width: 20, height: 20)
            EditorialLabel("Little Tide")
            Spacer()
            Button { isChoosingCoast = true } label: {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Change coast")
            .accessibilityIdentifier("changeCoast")
            Button { isShowingSettings = true } label: {
                Image(systemName: "gearshape").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settings")
        }
        .foregroundStyle(Palette.ink)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let format = TideFormat(timeZone: station.timeZone ?? .gmt, unit: model.unit)
        switch model.forecastState {
        case .idle, .loading:
            CoastStateView(station: station, kind: .loading)
        case let .failed(error):
            CoastStateView(station: station, kind: .failed(error), retry: { model.refresh(manual: true) }, chooseAnother: { isChoosingCoast = true })
        case let .ready(forecast, refreshError):
            if forecast.stationID != station.id {
                CoastStateView(station: station, kind: .loading)
            } else if !TideEngine.freshness(of: forecast, at: now).isUsable {
                CoastStateView(station: station, kind: .expired(forecast.fetchedAt, format), retry: { model.refresh(manual: true) }, chooseAnother: { isChoosingCoast = true })
            } else {
                CoastReadyView(
                    station: station, forecast: forecast, refreshError: refreshError, now: now, format: format,
                    selection: $selection, dayOffset: $dayOffset, showSource: { isShowingSource = true }
                )
            }
        }
    }
}

extension AppModel {
    func refreshAndWait() async {
        refresh(manual: true)
        while isRefreshing { try? await Task.sleep(for: .milliseconds(100)) }
    }
}

/// Paper strip behind the status bar so scrolled content never collides with it.
private struct StatusBarBacking: View {
    var body: some View {
        GeometryReader { proxy in
            Palette.paper
                .frame(height: proxy.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
