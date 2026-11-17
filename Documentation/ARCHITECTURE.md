# Architecture

Native SwiftUI app plus a WidgetKit extension, sharing one local Swift package. No
third-party dependencies, no server.

```
LittleTide (app)                LittleTideWidgets (extension)
  App/  AppModel (@Observable, MainActor) ─┐      CoastTimelineProvider
  Features/ CoastHome, CoastSearch,        │      CoastWidgetEntryView
            TideTimeline, Onboarding,      │        system: Small/MediumCoastCard
            Settings                       │        accessory: AccessoryCoastView
            │                              │
            ▼                              ▼
Packages/TideKit
  TideKit   Domain (TideStation, TideForecast, TideEvent, TideSample, CoastRegion)
            Data   (NOAARequest, NOAATideClient, NOAADecoder, FileForecastCache,
                    TideRepository, StationCatalog + bundled stations.json)
            TideEngine (StationDay, TimeZone resolver, trend/height/next event, freshness)
            Shared (SharedSettings, RecentCoasts, CoastWidgetContent, WidgetTimelinePlanner,
                    TideFormat, AccessoryText, SharedContainer = App Group)
  TideUI    Palette, Typography (Newsreader + SF), LiquidGlass, PaintedCoast +
            TideScene.metal, widget cards, accessory faces
  ArtForge  offline scene generator (land/water/data layers, widget snapshots, chart fill)
  CatalogBuilder  regenerates stations.json from NOAA metadata
```

## Data flow (one source of truth)
1. The user picks a `TideStation` (search, featured, recent, or widget deep link).
   `AppModel.select` records the previous coast in `RecentCoasts`, persists both through
   `SharedSettings` (App Group `UserDefaults`, versioned JSON), clears the old forecast, and
   reloads widget timelines.
2. `AppModel.refresh` shows the cached forecast immediately, then asks `TideRepository`.
   A per-request token (`isCurrent`) drops any response for a coast that is no longer
   selected, so out-of-order replies can never appear under the wrong name (tested).
3. `TideRepository` dedupes concurrent requests, rate-limits manual refreshes, falls back to
   the dated cache with the error attached, and refuses to present expired data as current.
4. `NOAATideClient` requests GMT, metric, MLLW from CO-OPS: hi/lo always, 15-minute samples
   only for reference stations. Bounded retry with backoff on throttling; no retry offline.
5. Views derive everything from `(forecast, instant, TideFormat)`: `TideEngine` answers
   trend, height, next event, day range and freshness. The hero, card, readout, coast
   window, chart and widgets all read the same functions, so they cannot disagree.
6. The widget reads the same App Group cache and settings, builds `CoastWidgetContent` per
   timeline entry, and reloads after the next event (`WidgetTimelinePlanner`).

## Time
All instants are UTC `Date`s. Display uses the station's civil IANA zone (resolved by
`StationTimeZoneResolver`, never NOAA's fixed offsets) through `TideFormat` and
`StationDay`, so 23- and 25-hour DST days and events after local midnight land on the
right station day. Tested with real Chatham (fall-back), Pensacola and Juneau data.

## Rendering
- `PaintedCoastView` draws one Metal `colorEffect` shader (`TideScene.metal`) over a
  three-panel atlas (land | water | data). The waterline is the normalised predicted level
  mapped into the scene's height field: an illustration of the prediction, not a model of a
  real beach.
- Glass panels report their frames through a `PreferenceKey` in a named coordinate space;
  the shader refracts the painting inside those rounded rects (glass-studies optical
  model). Reduce Transparency switches to opaque panels drawn by SwiftUI.
- The animation `TimelineView` pauses under Reduce Motion, when the app is not active, and
  when the scene is mostly scrolled out of view (`HomeLayout.isHeroVisible` /
  `areDetailsVisible`, driven by `onGeometryChange`).
- Widgets cannot run shaders: ArtForge pre-renders five tide levels per scene and family.

## Persistence
- `SharedSettings`: selected station (`selectedStation.v1`), recent coasts
  (`recentStations.v1`), unit, treatment. Missing or corrupt values read as defaults.
- `FileForecastCache`: one versioned JSON file per station in the App Group container;
  other schema versions and corrupt files are discarded, file names are sanitised.

## Testing layers
- `TideKitTests` (Swift Testing): decoding of real NOAA responses, engine, DST, catalog,
  repository, cache, widget content, recents, accessory text. Opt-in live NOAA comparison.
- `LittleTideTests` (XCTest): app model races, persistence, deep links, typography.
- `LittleTideUITests` (XCUITest): journeys with captured NOAA data and a fixed clock,
  measured-contrast accessibility audits, AX-XXL layout, opt-in Home Screen widget
  installation and rendering-cost probes.
