# Little Tide

**A little window into your coast.** Choose a NOAA tide-prediction station and see the next
predicted high or low over a painted aerial coast whose water follows the prediction, in
Home Screen and Lock Screen widgets, and in a day of tide you can explore with a finger.

- Real NOAA CO-OPS predictions (3,228 US stations), shown in each station's own civil time.
- A 15-minute predicted curve where NOAA publishes one. Subordinate stations show only their
  published highs and lows, with nothing invented in between.
- Original painted coasts (three regional scenes) rendered by a Metal shader whose waterline
  follows the predicted level, with liquid glass that refracts the painting. Labeled as
  illustrations, never as live views.
- Recent coasts one tap away; widgets for the Home Screen (small, medium) and Lock Screen
  (inline, circular, rectangular).
- Works offline from dated, cached predictions and says when they are too old to use.
- No accounts, ads, analytics, tracking or location.

Not for navigation or safety decisions. Little Tide is independent of NOAA.

## Requirements
- Xcode 26.6+ (Apple requires Xcode 26 / iOS 26 SDK for uploads since 28 Apr 2026)
- iOS 17.0+ deployment target, iPhone only
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ (`brew install xcodegen`)
- No third-party Swift packages

## Build, run, test
```bash
xcodegen generate
```
```bash
xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build
```
```bash
xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```
```bash
cd Packages/TideKit && swift test
```
```bash
cd Packages/TideKit && LITTLETIDE_LIVE=1 swift test --filter LiveNOAAComparison
```
Home Screen widget QA (installs widgets on the simulator, needs network):
```bash
TEST_RUNNER_LT_WIDGET_QA=1 xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:LittleTideUITests/WidgetHomeScreenTests/testChooseCoastThenInstallWidgets test
```
Archive (needs your Apple Developer team, see `Documentation/APP_STORE.md`):
```bash
xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -configuration Release -destination 'generic/platform=iOS' -archivePath build/LittleTide.xcarchive archive DEVELOPMENT_TEAM=YOURTEAMID
```
Regenerate the station catalog from NOAA metadata, then the app icon:
```bash
cd Packages/TideKit && swift run -c release catalog-builder
```
```bash
swift Tools/make-icon.swift
```

Opt-in rendering cost probe (XCTCPUMetric, XCTMemoryMetric):
```bash
TEST_RUNNER_LT_PERF=1 xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:LittleTideUITests/RenderingPerformanceTests test
```
Regenerate the painted scenes and widget snapshots:
```bash
cd Packages/TideKit && swift build -c release --product art-forge && .build/release/art-forge
```

DEBUG builds accept `-LTDemo <onboarding|curve|highLow|offline|failure|expired|slow|live>`
(plus `-LTNow <ISO8601>`) to run against captured NOAA responses with a fixed clock.
Release builds exclude this code.

## Layout
```
LittleTide/            app: App/, Features/{Onboarding,CoastSearch,CoastHome,TideTimeline,Settings}, UITestSupport/ (DEBUG)
LittleTideWidgets/     WidgetKit extension (small, medium, Lock Screen inline/circular/rectangular)
Packages/TideKit/      TideKit: Domain, Data (NOAA client, cache, repository, catalog), TideEngine, Shared
                       TideUI: palette, type, liquid glass, painted coast + TideScene.metal, widget faces
                       ArtForge: generates the painted scenes and widget snapshots
                       CatalogBuilder: regenerates stations.json from NOAA metadata
LittleTideTests/       app unit tests      LittleTideUITests/   UI + Home Screen tests
Documentation/         data, privacy, support, App Store kit, evidence, screenshots, media
Tools/                 icon generator, screenshot helper
```

## Documents
- Status: [PROGRESS.md](PROGRESS.md) · [Documentation/QA_REPORT.md](Documentation/QA_REPORT.md) ·
  [Documentation/APP_STORE.md](Documentation/APP_STORE.md) (App Store readiness)
- Audits: [Documentation/BASELINE_AUDIT.md](Documentation/BASELINE_AUDIT.md) ·
  [Documentation/BASELINE_TESTS.md](Documentation/BASELINE_TESTS.md) ·
  [Documentation/PRODUCT_AUDIT.md](Documentation/PRODUCT_AUDIT.md) ·
  [Documentation/REFERENCE_AUDIT.md](Documentation/REFERENCE_AUDIT.md) ·
  [Documentation/COMPETITORS.md](Documentation/COMPETITORS.md) · [SOURCE_AUDIT.md](SOURCE_AUDIT.md) ·
  [VISUAL_AUDIT.md](VISUAL_AUDIT.md)
- Design and engineering: [Documentation/DESIGN_SYSTEM.md](Documentation/DESIGN_SYSTEM.md) ·
  [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) ·
  [Documentation/DATA.md](Documentation/DATA.md) · [Documentation/ACCESSIBILITY.md](Documentation/ACCESSIBILITY.md) ·
  [Documentation/TYPOGRAPHY.md](Documentation/TYPOGRAPHY.md) · [IMAGE_CREDITS.md](IMAGE_CREDITS.md)
- Product: [Documentation/PRODUCT_REFINEMENT.md](Documentation/PRODUCT_REFINEMENT.md) ·
  [CASE_STUDY.md](CASE_STUDY.md) · [Documentation/PRIVACY.md](Documentation/PRIVACY.md) ·
  [Documentation/SUPPORT.md](Documentation/SUPPORT.md)

The refinement brief's `docs/` paths map onto `Documentation/` (one doc tree).
