# Little Tide — progress log

Resumable record of what is done, verified and blocked. Newest first within each milestone.

## Environment (verified 2026-11-16)
- macOS 26.4.1, Xcode 26.6 (17F113), Swift 6.3.3, iOS 26.4/26.5 simulators.
- GitHub CLI authenticated. **No code-signing identity / Apple Developer team on this Mac.**
- XcodeGen 2.46.0 (Homebrew) generates `LittleTide.xcodeproj` from `project.yml`.

## M0 — Audit and foundation ✅
- Reference repos audited → `SOURCE_AUDIT.md`.
- Live NOAA probing: 3,502 prediction stations (1,260 R / 2,242 S). Findings:
  - `lst_ldt` follows DST for Eastern/Central/Pacific/Alaska(−9) stations but **not** for
    Alaska stations tagged −10/−11; some metadata offsets are wrong (Indian Rocks Beach FL,
    Sabine Pass TX). → Little Tide fetches GMT and displays station civil time from an IANA
    zone derived from state + longitude/latitude (`StationTimeZoneResolver`).
  - Subordinate stations reject `interval=15` (HTTP 200 + `error`). Bad station/date → 400
    + `{"error":{"message"}}`. Rate limiting → 403 `{"message":"Forbidden"}` (triggered by
    ~70 rapid probe requests; cleared within minutes). `begin_date=yyyyMMdd HH:mm` + `range` works.
- Scaffold: app + WidgetKit extension + unit/UI test bundles + local `TideKit` package.
  Debug simulator build succeeds; app launches on iPhone 17 Pro (iOS 26.5).
  Simulator binaries carry the App Group entitlement.

## M1 — Tide domain and data ✅
- TideKit: domain models, NOAA request/decoder/client (retry + backoff), versioned file
  cache, repository actor (cache-first, dedupe, offline fallback), pure TideEngine,
  station-day/DST helpers, catalog (3,228 US stations) + search, widget timeline planner.
- 67 package tests pass (`swift test`).
- Live comparison vs NOAA's own published lst_ldt/english predictions: 5 stations
  (CA, ME, HI, FL, NY-subordinate), every event identical to the minute, heights within
  0.001 ft → `Documentation/Evidence/noaa-live-comparison.txt`.

## M2 — Identity and app interaction ✅ (first pass; polish continues in M4)
- Original illustration system (6 coast regions, painted + line styles), waterline driven
  by the normalised predicted height at the selected instant (neutral when no height).
- Home: postcard, place title, Now summary (trend only when defensible), tide study with
  scrub, haptics at real extrema, day paging, Now reset, highs/lows table, provenance footer,
  source sheet. High/low-only stations show event stems and snap selection to events.
- States: loading, offline-with-dated-cache banner, expired ("Forecast unavailable"),
  failure with retry/choose another. Search: featured coasts, browse by state, debounced
  search, honest no-match guidance.
- Fixed during QA: clipped first hour label; edge pile-up of off-window samples; low-label
  collision; status-bar overlap on scroll; source sheet used device time zone; expired
  cache + failed refresh showed generic error instead of "Forecast unavailable".
- Tests: 68 package + 2 app unit + 8 UI tests (onboarding→search→choose, no-match, scrub→Now,
  HL snapping, offline, expired, failure, loading, units→meters, source sheet) all pass.
  Screenshots: `Documentation/Screenshots/app/`.

## M3 — Home-screen widgets ✅
- Small + medium WidgetKit widgets (StaticConfiguration, one chosen coast in V1), timeline
  from cached predictions via `WidgetTimelinePlanner` (30-min marker steps, an entry 1 s
  after every event, reload ≤ 6 h or at the last known event), App Group cache + settings,
  widget-side refresh only when the repository says it is due. Deep link
  `littletide://station/<id>`; unconfigured and expired states.
- **Verified on the iOS 26.5 simulator's real Home Screen** with live NOAA data
  (`WidgetHomeScreenTests`, opt-in via `TEST_RUNNER_LT_WIDGET_QA=1`): both sizes installed
  through the widget gallery; tapping a widget opens the app on the same coast; full-colour
  light/dark, Tinted and Clear styles captured → `Documentation/Screenshots/widgets/`.
  Widget showed Low 9:13 PM 0.8 ft for Santa Monica, matching NOAA (21:13, 0.798 ft).
- Widget content model unit-tested (mismatched station never shown, expiry, aging note,
  no invented level for high/low-only stations): 72 package tests pass.
- QA side effects on the simulator Home Screen (not the app): automation accidentally added
  a Contacts widget to page 2 and, while trying to remove it, removed the stock Maps widget
  from page 1. The position-based removal test was deleted.

## Blockers needing the owner
- Apple Developer team ID + signing for device install, archive and TestFlight.
