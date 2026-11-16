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

## M1 — Tide domain and data (in progress)
- TideKit: domain models, NOAA request/decoder/client (retry + backoff), versioned file
  cache, repository actor (cache-first, dedupe, offline fallback), pure TideEngine,
  station-day/DST helpers, catalog (3,228 US stations) + search, widget timeline planner.
- 67 package tests pass (`swift test`).
- Live comparison vs NOAA's own published lst_ldt/english predictions: 5 stations
  (CA, ME, HI, FL, NY-subordinate), every event identical to the minute, heights within
  0.001 ft → `Documentation/Evidence/noaa-live-comparison.txt`.

## Blockers needing the owner
- Apple Developer team ID + signing for device install, archive and TestFlight.
