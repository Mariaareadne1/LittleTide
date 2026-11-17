# Baseline audit (2026-11-17, commit d9c9064)

Recorded before the refinement brief's milestones. The brief's `docs/` paths map onto
the repository's existing `Documentation/` folder (one doc tree, not two).

## Stack (inspected, not assumed)
- **Native SwiftUI**, iOS 17 deployment target, Swift 6 strict concurrency. Xcode 26.6,
  iOS 26.5 SDK. No React Native, Expo or web layer.
- XcodeGen `project.yml` → `LittleTide.xcodeproj`. Targets: app, `LittleTideWidgets`
  (WidgetKit), `LittleTideTests`, `LittleTideUITests`.
- Local SwiftPM package `Packages/TideKit`: `TideKit` (domain, NOAA client, engine, cache,
  shared settings), `TideUI` (type, palette, glass, painted coast, Metal shader, widget
  views), `CatalogBuilder` (bundled station catalog), `ArtForge` (scene generator).
- No third-party dependencies. No SwiftLint/SwiftFormat installed.

## Implemented and verified working
| Feature | Where | Evidence |
|---|---|---|
| NOAA CO-OPS predictions (hi/lo + 15-min curve), GMT requests, station-zone display | `TideKit/Data`, `TideEngine` | 21 decoder/request tests, live comparison test (opt-in) |
| Subordinate (hi/lo-only) stations, no invented curve | `TideEngine`, `TideStudyView` | tests + `20/21-home-highlow` screenshots |
| Bundled US station catalog, search by town/state/ID, browse by state | `StationCatalog`, `CoastSearchView` | tests + `02–04-search` |
| Selection persistence (App Group) | `SharedSettings`, `AppModel` | `testSelectionPersistsAcrossRelaunch` |
| Out-of-order responses never shown under a new coast | `AppModel.isCurrent` | `testSlowResponseForPreviousCoastIsNeverShownUnderNewCoast` |
| Offline cache, aging/expired states, rate-limited refresh, bounded retry/backoff | `ForecastCache`, `TideRepository` | 7 repository tests + `30–33` screenshots |
| Scrubbable curve, day pager −1…+6, Now button, haptics at events | `TideStudyView`, `CoastReadyView` | `testCurveScrubAndReturnToNow` |
| Painted coast (3 regions), illustrative waterline, people/boats, shader glass | `PaintedCoast`, `TideScene.metal` | screenshots in `Design/reconstruction` |
| Small + medium widgets, full-color/accented, deep link to station | `LittleTideWidgets`, `CoastWidgetViews` | Home Screen test (opt-in) + screenshots |
| Settings: units, haptics, refresh, clear cache, privacy, credits, support | `SettingsView` | `testUnitsAndSourceSheet` |

## Not present
- Location permission (manual coast choice only; no `NSLocation*` keys). Deliberate.
- Saved/recent coasts beyond the single selected one.
- Lock Screen (accessory) widgets.
- CI workflow.

## Known issues found at baseline (evidence: `Baseline/Screenshots`)
1. **Offline/aging state is below the fold.** The "Offline · showing predictions retrieved…"
   banner sits under the hero, so the first screen shows the card without any staleness cue
   (`30-offline-cached.jpg`).
2. **Scrolled title collides with the status bar.** "Santa Monica" and the region label
   slide under the clock before the scrim is opaque (`11-home-scrubbed.jpg`).
3. **Hero waterline on other days** is normalised against *today's* range while showing
   the selected day's height, so it can clip at 0 or 1 when paging days
   (`CoastReadyView.heroLevel`).
4. **Only one coast.** Switching back to a previous coast means searching again.
5. **Contrast margins on art are thin** in places (4.53:1 onboarding pill, fixed in d9c9064).

## Assets and licences
See `IMAGE_CREDITS.md` and `Documentation/TYPOGRAPHY.md`: all imagery is original
(ArtForge / in-code), fonts are Newsreader (OFL 1.1) + SF Pro (system). No photographs.

## Persistence and migration risk
`SharedSettings` (App Group `UserDefaults`, Codable, survives corruption) and versioned
forecast cache files (`discardsOtherSchemaVersionsAndCorruptFiles`). Any new stored field
must decode old payloads (tested when added).
