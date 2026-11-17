# Baseline tests (2026-11-17, commit d9c9064)

Command (iPhone 17 Pro simulator, iOS 26.5):

```bash
xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -destination "platform=iOS Simulator,id=4739D449-66FC-4503-96D1-DB6B285552DD" -derivedDataPath build/DD test
```

Result: **95 tests — 92 passed, 0 failed, 3 skipped.** Skipped tests are opt-in:
- `WidgetHomeScreenTests.testChooseCoastThenInstallWidgets` and `testHomeScreenStyle`
  (drive SpringBoard; run with `TEST_RUNNER_LT_WIDGET_QA=1`).
- `LiveNOAAComparisonTests.matchesNOAAPublishedPredictions` (hits the network; run with
  `LT_LIVE_NOAA=1`).

| Suite | Tests |
|---|---|
| TideKit: NOAA decoder/request | 21 |
| TideKit: station catalog | 12 |
| TideKit: heights & interpolation | 7 |
| TideKit: repository/cache | 7 |
| TideKit: widget content + timeline | 7 + 4 |
| TideKit: next/previous event | 6 |
| TideKit: rising/falling | 5 |
| TideKit: time zones / DST | 2 groups (6 cases) |
| App: model, deep links, typography | 3 + 2 + 4 |
| UI: journeys + states | 8 |
| UI: accessibility audits (pixel-measured contrast) | 4 |
| UI: Home Screen widgets (opt-in) | 2 |

Lint/format: none configured (no SwiftLint/SwiftFormat installed). Release archive:
`xcodebuild … -configuration Release archive CODE_SIGNING_ALLOWED=NO` succeeded with 0
warnings; `.app` 24 MB.

Fixture coverage gap at baseline: recorded NOAA responses exist for Pacific (Santa Monica
9410840), subordinate (King Harbor 9410738), Hawaii (French Frigate Shoals 1619222) and
error cases, but **not Atlantic, Gulf or Alaska**.
