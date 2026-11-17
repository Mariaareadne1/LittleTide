# Little Tide: design-engineering case study

A design-led iPhone utility for people who feel connected to a particular stretch of US
coast: a painted aerial coast whose water follows NOAA's predicted tide, liquid glass that
bends the painting, and Home Screen and Lock Screen widgets.

## Context and problem
Tide information is genuinely useful, and good tide apps exist. Tide Guide is a polished,
dense instrument with Editors' Choice. Ocean Watch is free, NOAA-based and collects no
data. What they share is a table-and-chart language built for planning. The design
question here was different: can the tide be *felt* at a glance, as a picture of your coast
at this hour, without giving up accuracy or honesty? (`Documentation/COMPETITORS.md`.)

## Principles
1. **Truthfulness is a design material.** Show "Rising" only when the data supports it; draw
   no curve where NOAA publishes only highs and lows; label stale data where the claim is
   made; call the painted waterline illustrative.
2. **The coast is the interface.** Information floats on glass over the painting rather
   than living in cards on a white page.
3. **One coast, one glance.** Next event first, everything else quieter.

## Iterations
| Stage | What changed | Evidence |
|---|---|---|
| M0–M6 (first build) | NOAA engine, search, timeline, widgets, procedural side-view illustrations on cream paper | `Documentation/Screenshots/` |
| Typography and glass | Newsreader + SF Pro (Canela not licensable for app embedding), iOS glass | `Documentation/Design/before`, `after` |
| Reconstruction | Aerial painted coasts from an approved reference: ArtForge height fields, Metal tide shader, three regions | `Documentation/Design/reconstruction/` |
| Liquid glass | glass-studies optical model ported into the shader so glass refracts the painting; people and boats placed where the tide stays truthful | `reconstruction/m3-*.jpg` |
| Refinement (this brief) | Baseline audit and scorecard, regional NOAA fixtures, staleness on the first screen, recent coasts, coast window synced to scrubbing, Lock Screen widgets, AX-XXL and iPhone SE layouts, rendering pause | `Documentation/Baseline/`, `Documentation/Design/refinement/` |

## Design decisions worth explaining
- **Why paint instead of photographs?** Photography needs per-image licensing and can't
  show low and high water from the same viewpoint. A generated height field can: the shader
  floods the same terrain to any predicted level, so the picture changes for a reason.
- **Why glass in the shader?** SwiftUI materials blur whatever is behind them, but the
  painting is a shader output, so system glass could only frost it. Rendering glass inside
  the same shader lets it refract the actual sand and foam (IOR 1.52, Fresnel, chromatic
  split) while text stays on a deep-teal absorbing layer that keeps contrast above 4.5:1.
- **Why a coast window?** Scrubbing happens below the fold, where the hero is invisible.
  A wide crop of the same painting follows the scrubbed time, so dragging to 9:13 PM
  visibly uncovers the beach; VoiceOver hears "Water near the day's low".
- **Why recent coasts, not favourites?** The audit found switching coasts was the main
  daily-use gap; remembering the last four choices solves it with no new screens.

## Technical implementation
- **Data:** NOAA CO-OPS requested in GMT and metric, displayed in each station's civil IANA
  zone (resolved locally because NOAA's offsets are wrong for some stations). Curves only
  for reference stations; hi/lo-only stations never get an invented curve.
- **Correctness:** 89 package tests include real recorded responses from the Pacific,
  Atlantic across a DST change, a diurnal Gulf station, Alaska, Hawaii and a subordinate
  station. A live comparison matched NOAA's own local-time tables at 7/7 stations.
- **State:** one `AppModel` and pure `TideEngine` functions feed the hero, card, readout,
  coast window, chart and widgets, so they cannot disagree; a request token prevents
  out-of-order responses from showing under the wrong coast.
- **Widgets:** pure `CoastWidgetContent` per entry, pre-rendered painted snapshots (widgets
  can't run shaders), line art in tinted/clear, Lock Screen faces in system monochrome.
- **Performance:** scenes pause when mostly off-screen or inactive. On a loaded simulator
  the scrolled-state CPU fell from 0.64 s to about 0.53 s per 5 s; GPU cost needs a device.

## Evidence
- Tests: see `Documentation/QA_REPORT.md` for exact commands and results.
- Screenshots: `Documentation/Baseline/Screenshots/` (before) and
  `Documentation/Design/refinement/` (after); widgets on a real simulator Home Screen.
- Recordings: `Documentation/Media/` (widget to app, scrubbing, choosing a coast). They
  predate the painted redesign.

## Results
No users, downloads, revenue or reviews yet: the app has not been submitted. It builds,
passes its suites, archives in Release with 0 warnings, and runs with real NOAA data on the
simulator. Signing and TestFlight need the owner's Apple Developer account.

## Reflection
The redesign is better, not just prettier, where the picture carries information. The
waterline answers "is it out?" before any number is read, the glass keeps text legible
without hiding the coast, and every claim on screen is backed by NOAA data or labelled as
illustration. The remaining risks are on hardware: shader cost, haptics and VoiceOver by
ear have only been checked on the simulator.
