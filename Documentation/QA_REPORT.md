# QA report (2026-11-17)

Simulators: "LittleTide QA 17 Pro" (iPhone 17 Pro, iOS 26.5) and "LittleTide QA SE"
(iPhone SE 3rd gen, iOS 26.5), dedicated to this project. Xcode 26.6, Swift 6.3.3.
Everything below was executed; nothing is reported from memory.

## Automated suites
| Command | Result |
|---|---|
| `xcodebuild -project LittleTide.xcodeproj -scheme LittleTide -destination "platform=iOS Simulator,id=<17 Pro>" -derivedDataPath build/DDQA test` | **118 tests: 113 passed, 0 failed, 5 skipped** (opt-in: 2 Home Screen widget, 2 rendering probes, 1 live NOAA) |
| Same, `-only-testing:LittleTideUITests/LittleTideUITests -only-testing:LittleTideUITests/AccessibilityAuditTests` on iPhone SE | **15/15 passed** (journeys, AX-XXL layout, four measured-contrast audits) |
| `cd Packages/TideKit && swift test` | **89 tests passed** (1 live suite skipped) |
| `cd Packages/TideKit && LITTLETIDE_LIVE=1 swift test --filter LiveNOAAComparison` | **7/7 stations** match NOAA's published local-time, English-unit predictions (Santa Monica, Bar Harbor, Honolulu, Key West, Montauk subordinate, Pensacola, Juneau) |
| `TEST_RUNNER_LT_WIDGET_QA=1 … -only-testing:LittleTideUITests/WidgetHomeScreenTests/testChooseCoastThenInstallWidgets test` | **Passed**: small and medium installed on the real simulator Home Screen with live NOAA data; widget tap opens the app on the same coast |
| `xcodebuild … -configuration Release -destination 'generic/platform=iOS' archive CODE_SIGNING_ALLOWED=NO` | **Archive succeeded, 0 warnings**; `.app` 27 MB, widget 5.5 MB; no demo fixtures or test code in the bundle |

Lint/format: no SwiftLint or SwiftFormat is installed; the build runs Swift 6 strict
concurrency with 0 warnings.

## Coverage of the brief's test plan
| Area | Covered by |
|---|---|
| Atlantic, Pacific, Gulf, Alaska, Hawaii, subordinate, invalid station | Recorded fixtures (`Fixtures/README.md`) + `RegionalFixtureTests`, `NOAADecoderTests` |
| Rising/falling, before first/after last event, midnight, station vs device zone, DST | `TideEngineTests`, `StationDayTests`, `RegionalFixtureTests` (Chatham fall-back, Juneau date rollover) |
| Continuous vs hi/lo-only, units, datum, malformed payloads, timeout, offline, stale, throttling | Engine, decoder and repository suites |
| Rapid switching / out-of-order responses | `testSlowResponseForPreviousCoastIsNeverShownUnderNewCoast` |
| Scrubbing, return to Now, coast window follows selection | `testCurveScrubAndReturnToNow` (asserts readout and waterline: near high at 10:20, near low at 9:14 PM) |
| Hi/lo-only snapping | `testHighLowOnlyStationSnapsToEvents` |
| First launch → choose coast → predictions | `testFirstLaunchSearchAndChooseCoast` |
| Change coast and back via recents; persistence across relaunch | `testSwitchCoastAndBackFromRecents`, `testRecentCoastsFollowSelectionsAndPersist`, `testSelectionPersistsAcrossRelaunch` |
| Offline with cache, nothing cached, expired, loading | four UI state tests |
| Largest text, small screen | `testLargestAccessibilityTextKeepsTheTideReadable` on 17 Pro and SE |
| Widget content, timeline, Lock Screen text | `WidgetContentTests`, timeline planner tests, `AccessoryFormatTests` |

Location permission is not tested because the app does not request it (manual coast choice
only, by design).

## Performance (simulator, relative only)
`TEST_RUNNER_LT_PERF=1 … -only-testing:LittleTideUITests/RenderingPerformanceTests`, six
5-second iterations, machine heavily loaded by other work (load average 14–65):

| State | Before (86d9b54) | After |
|---|---|---|
| Idle, hero visible | 0.60 s CPU / 5 s (RSD 12 %) | 0.56 s (RSD 12 %) |
| Idle, scrolled to details | 0.64 s (RSD 9 %) | 0.52–0.55 s (RSD 17–24 %) |

The scene now pauses when mostly off screen, when the app is inactive and under Reduce
Motion (verified with a temporary log, then removed). The simulator's CPU metric does not
include the GPU work of the shader, so battery and thermal behaviour still need Instruments
on a device. Memory was recorded by `XCTMemoryMetric` in the same runs (see the result
bundles); no leak investigation was done beyond that.

App icon: the compiled asset catalog carries light, dark (`UIAppearanceDark`) and tinted
(`ISAppearanceTintable`) 1024 px renditions (`xcrun assetutil --info`), and the generated
`AppIcon60x60@2x.png` shows the painted coast.

## Visual inspection
Screenshots inspected for each change: `Documentation/Design/refinement/`
(offline-in-card and scrim, coast window low vs high, your coasts, widget guide with Lock
Screen faces, live Home Screen widgets, AX-XXL on 17 Pro and SE, iPhone SE journeys).
Found and fixed during inspection: scroll offset never updating (scrim invisible), the flat
band below the details, AX-size overflow past the screen edge, truncated tide time on SE,
colliding chart labels, a truncated coast-window caption.

## Not verified
- Lock Screen widgets placed on an actual Lock Screen (no lock-button automation); verified
  by build, unit tests and the in-app preview.
- Tinted and clear Home Screen styles after this refinement (verified in the earlier
  milestone; widget code paths unchanged except the new accessory families).
- Physical device: haptics, VoiceOver by ear, GPU cost, real widget refresh cadence.
- TestFlight upload and App Review (blocked on signing).

## Incident
`5e13248` was pushed with a failing accessibility audit (a capped caption flagged as
partial Dynamic Type support). Fixed in `df61dfe`; the final full run above is green.

## Type and copy polish (2026-11-17, unslop pass)
Sentence case replaces tracked capitals, the section heading is roman, small symbols drop from
bold to semibold, short lines lose their periods, chart markers pass behind event labels, and
the glass press scale eases to 0.97. Unused `EditorialLabel` and legacy `Typography` removed.
- `swift test` (Packages/TideKit): 89 passed.
- Full app suite on "LittleTide QA 17 Pro": TEST SUCCEEDED, 0 failures, 4 opt-in UI tests skipped.
- `LittleTideUITests` on "LittleTide QA 17 Pro Max": 11/11 passed; App Store screenshots in
  `AppStore/6.9in/` re-captured from that run.
- Not re-run: iPhone SE suite, Home Screen widget QA, live NOAA comparison, perf probe.

### Calmer button glass (same day)
Button glass: bevel `min(radius × 0.45, 10)` instead of the full radius, thickness 14, milk
0.4, specular 0.8, aberration 0.25. Affects the header buttons, day pager, Now button and the
onboarding caption pill.
- `LittleTideUITests` on "LittleTide QA 17 Pro Max": TEST SUCCEEDED; App Store screenshots
  re-captured.
- `AccessibilityAuditTests` on "LittleTide QA 17 Pro": first run hit "Audit failed to complete
  in time" on `testHomeCurveAudit` (an XCTest timeout, no finding); re-run 4/4 passed.
