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
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                let now = model.clock.now()
                ScrollView {
                    content(now: now, layout: layout(proxy))
                        // A geometry preference from inside the scroll content does not re-fire
                        // while scrolling; onGeometryChange (back-deployed to iOS 16) does.
                        // Quantised so the home view re-renders every few points, not every frame.
                        .onGeometryChange(for: CGFloat.self) { geometry in
                            (geometry.frame(in: .named("homeScroll")).minY / 8).rounded() * 8
                        } action: { offset in
                            scrollOffset = offset
                        }
                }
                .coordinateSpace(name: "homeScroll")
                .ignoresSafeArea(edges: .top)
                .refreshable { await model.refreshAndWait() }
            }
        }
        .background(LinearGradient(colors: [Palette.oceanMid, Palette.oceanDeep], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        // Invisible over the sky at rest; settles in as content scrolls under the status bar.
        .overlay(alignment: .top) { StatusBarScrim().opacity(min(max(-scrollOffset / 160, 0), 1)) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: model.station?.id)
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

    private func layout(_ proxy: GeometryProxy) -> HomeLayout {
        let height = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        return HomeLayout(
            width: proxy.size.width, height: height, topInset: proxy.safeAreaInsets.top,
            // Only the painting that is substantially on screen keeps animating. Once less than
            // ~45 % of the hero shows (just the card under the status scrim), it holds still.
            isHeroVisible: scrollOffset > -(height * 0.55),
            areDetailsVisible: scrollOffset < -(height * 0.3)
        )
    }

    private var actions: HeroActions {
        HeroActions(chooseCoast: { isChoosingCoast = true }, openSettings: { isShowingSettings = true },
                    openStationDetails: { isShowingSource = true })
    }

    @ViewBuilder
    private func content(now: Date, layout: HomeLayout) -> some View {
        let format = TideFormat(timeZone: station.timeZone ?? .gmt, unit: model.unit)
        switch model.forecastState {
        case .idle, .loading:
            CoastStateView(station: station, kind: .loading, layout: layout, actions: actions)
        case let .failed(error):
            CoastStateView(station: station, kind: .failed(error), layout: layout, actions: actions,
                           retry: { model.refresh(manual: true) }, chooseAnother: { isChoosingCoast = true })
        case let .ready(forecast, refreshError):
            if forecast.stationID != station.id {
                CoastStateView(station: station, kind: .loading, layout: layout, actions: actions)
            } else if !TideEngine.freshness(of: forecast, at: now).isUsable {
                CoastStateView(station: station, kind: .expired(forecast.fetchedAt, format), layout: layout, actions: actions,
                               retry: { model.refresh(manual: true) }, chooseAnother: { isChoosingCoast = true })
            } else {
                CoastReadyView(
                    station: station, forecast: forecast, refreshError: refreshError, now: now, format: format,
                    layout: layout, actions: actions, selection: $selection, dayOffset: $dayOffset,
                    showSource: { isShowingSource = true }
                )
            }
        }
    }
}

struct HomeLayout {
    let width: CGFloat
    /// Full screen height including safe areas: the hero fills it.
    let height: CGFloat
    let topInset: CGFloat
    var isHeroVisible = true
    var areDetailsVisible = true
}

extension AppModel {
    func refreshAndWait() async {
        refresh(manual: true)
        while isRefreshing { try? await Task.sleep(for: .milliseconds(100)) }
    }
}
