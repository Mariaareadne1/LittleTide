# Little Tide — progress log

Resumable record of what is done, verified and blocked. Newest first within each milestone.

## Environment (verified 2026-11-16)
- macOS 26.4.1, Xcode 26.6 (17F113), Swift 6.3.3, iOS 26.4/26.5 simulators.
- GitHub CLI authenticated. **No code-signing identity / Apple Developer team on this Mac.**
- XcodeGen 2.46.0 (Homebrew) generates `LittleTide.xcodeproj` from `project.yml`.

## Refinement brief (2026-11-17) — consumer-quality audit and hardening
Brief `docs/` paths map onto `Documentation/`. Dedicated simulators: "LittleTide QA 17 Pro"
(F8902CF2-…) and "LittleTide QA SE" (818E8A1D-…); the shared iPhone 17 Pro is also used by
another project's UI tests.

| Milestone | Commit | Result |
|---|---|---|
| R0 baseline | `0453b62` | `BASELINE_AUDIT.md`, `BASELINE_TESTS.md` (95: 92 pass, 3 opt-in skip), `PRODUCT_AUDIT.md` scorecard + top-5 weaknesses, `COMPETITORS.md`, baseline screenshots |
| R1 data | `86d9b54` | Real Atlantic (Chatham, DST), Gulf (Pensacola, diurnal), Alaska (Juneau) fixtures + 10 tests; live comparison 7/7 stations |
| R2–R3 home | `e37da96` | Recent coasts; staleness in the tide card; scroll offset bug fixed (scrim never appeared); scenes pause off-screen; hero level uses displayed day; `REFERENCE_AUDIT.md` |
| R4 timeline | `43402ad` | Coast window follows scrubbing; VoiceOver value; UI test asserts high → low |
| R5 widgets | `a2ef8f9` | Lock Screen inline/circular/rectangular; guide preview; Home Screen widgets re-verified live |
| R6 accessibility | `5e13248`, `df61dfe` | AX-XXL and iPhone SE layouts; hero grows; no truncation; chart labels capped |
| R7–R8 QA and docs | this commit | `QA_REPORT.md`, `ARCHITECTURE.md`, `DESIGN_SYSTEM.md`, `PRODUCT_REFINEMENT.md`, case study rewrite, App Store readiness table, new demo |

Final verification: 118 tests, 113 passed, 0 failed, 5 skipped (opt-in); SE 15/15;
package 89; Release archive 0 warnings (27 MB app with the painted icon, 5.5 MB widget).

Next, in order: owner signing steps (`Documentation/APP_STORE.md`), then on-device checks
(GPU cost in Instruments, haptics, VoiceOver, Lock Screen placement), then recapture
6.9" App Store screenshots from the painted build. Candidates after V1: sunrise/sunset
marks, configurable widget station.

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

## M4 — Personalisation and polish ✅
- Original app icon (light/dark/tinted) generated by `Tools/make-icon.swift`.
- Settings: feet/metres (persisted, shared with widgets), haptics toggle, refresh, clear
  cache, live widget preview from current data, widget guide, privacy/credits/support.
- Name casing keeps acronyms (USCG); caption wraps at large text sizes.
- AppModel tests: slow response for a previous coast never shown under the new one;
  selection + units survive relaunch; unknown deep links ignored.
- Visual QA: iPhone 17e + 17 Pro, light/dark, Accessibility-L text, longest catalog names
  (layout tests use DEBUG fixtures under other names; marked `layouttest`).
- Full regression: 87 tests — 84 passed, 0 failed, 3 skipped (opt-in Home Screen QA ×2,
  live NOAA suite). Unsigned Release archive succeeds; demo code/fixtures excluded.
- Personal photo (PhotosPicker) deliberately deferred: the free V1 is complete without it.

## M5 — Optional purchase: deferred
No StoreKit code ships. Rationale: the free product is complete; Plus features (favourites,
alternate compositions, personal photos) are not built, and no App Store Connect product
exists. Shipping a paywall without them would be inert. See `Documentation/APP_STORE.md`.

## M6 — Launch package ✅ (owner steps remain)
- Docs: README, DATA, PRIVACY, SUPPORT, ACCESSIBILITY, APP_STORE (listing, keywords, privacy
  and age answers, reviewer notes, screenshot plan, demo scripts), IMAGE_CREDITS, CASE_STUDY.
- Demo clips (`Documentation/Media/`): widget → app (live data), scrubbing (captured NOAA
  data, fixed clock), choosing a coast.
- Accessibility audit tests added; fixed header contrast, badge element, caption type.
- Final regression 2026-11-16: 91 tests, 88 passed, 0 failed, 3 skipped by design.
  Live NOAA comparison re-run: 5 stations, 20/20 events identical. Unsigned Release
  archive succeeds with 0 warnings.

## Design refinement: Canela-direction typography, painterly art, glass (2026-11-16)
- Audit: the repo had New York + SF and flat vector art; the "painterly art + liquid
  glass" described in the brief did not exist yet and was built here.
- Fonts: no licensed Canela available → **Newsreader** (OFL, variable opsz/wght) bundled
  in TideUI; centralised `TypeStyle` system; `BrandTypeface` switch for a future Canela
  licence. See `Documentation/TYPOGRAPHY.md`.
- Art: painterly procedural renderer (sky glow/clouds, regional land, deep→turquoise
  water, swells, glitter, caustics, foam lace, wet sand, grain); NorCal/SoCal split;
  static/dynamic layers rasterised separately.
- Home: edge-to-edge hero whose horizon follows the title; glass region pill; floating
  Liquid Glass tide card (iOS 26 `glassEffect`, material fallback, opaque under Reduce
  Transparency); glass header buttons, date pager, Now button; truthful display names
  (trailing parenthetical → subtitle).
- Widgets: painted `containerBackground` with paper veil, serif hero time, SF labels;
  line art in tinted/clear; app reloads widget timelines on launch. Verified on the real
  Home Screen in light/dark/tinted/clear.
- Accessibility audits now measure real pixel contrast for flagged elements (all 7.4–10.9:1).
- Regression: 95 tests — 92 passed, 0 failed, 3 skipped (opt-in). Final run after polish
  identical; Release archive 0 warnings (fonts + OFL in app and widget); live NOAA 20/20.
- Polish: status-bar scrim fades in with scroll; Reduce Transparency verified.

## Visual reconstruction (reference: aerial painterly coast + teal Liquid Glass)
- `VISUAL_AUDIT.md`: file map, gap analysis, decision. The reference's "Nauset Beach
  8449920" is not a NOAA station → Chatham 8447435 with verified editorial label
  "Chatham / Cape Cod, MA" (`EditorialNames`).
- Metal Toolchain (Apple, 687.9 MB) installed with the owner's approval to compile shaders.
- M1 ✅ East Coast painted scene: ArtForge generator + Metal tide shader + full-screen
  composition with real NOAA data. Functional tests pass (90/95; 3 opt-in skipped); the two
  home accessibility audits fail only for regions still on the old illustration (fixed in M2).

- M2 ✅ NorCal + SoCal painted scenes, region mapping, painted widget snapshots (Home Screen
  verified light/dark/tinted), painted onboarding, measured-contrast audits all passing,
  layers moved to app bundle (Release app 24 MB, widget 5.1 MB). Regression 95 tests:
  92 passed, 0 failed, 3 skipped (opt-in); live NOAA comparison still passes.

- M3 ✅ People and boats painted into all three scenes (above the high-tide line or in deep
  water, so tide truthfulness holds). The glass-studies optical model is ported into the
  Metal scene shader, so every glass panel refracts the painting. Reduce Transparency
  gives opaque panels. Regression 95 tests: 92 passed, 0 failed, 3 skipped. Release
  archive has 0 warnings, app 24 MB.

## Blockers needing the owner
See `Documentation/APP_STORE.md` → "Owner-only steps". In short:
- Apple Developer team ID + signing → device install, signed archive, TestFlight.
- Register bundle IDs + App Group (placeholders `app.littletide.*`).
- Check "Little Tide" name availability in App Store Connect.
- Add a public support email to SUPPORT.md. (Privacy and support pages are public as of
  2026-11-17, since the repo is public; the app links to both.)
- Optional: approve sourcing licensed / public-domain coastal photographs.
- Optional: buy a Commercial Type mobile-app licence for Canela (see TYPOGRAPHY.md).
- On-device checks not possible here: haptics, VoiceOver by ear, real widget refresh cadence.
