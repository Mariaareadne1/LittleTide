# Little Tide: design-engineering case study

## Problem
Tide apps tend to be dashboards, built for boaters and surfers and dense with numbers.
Plenty of people only want a calm, glanceable answer to "when is the tide out at my beach?",
plus a way to feel the shape of the day. They don't want marine instrumentation.

## Audience
People who live near, walk, or love a particular stretch of US coast: tide-poolers,
dog-walkers, beachcombers, and people far from a coast they miss.

## Differentiation
The product is not a forecast hub. It is one coast, one honest number, and one tactile
timeline. Each choice serves that:
- **A postcard, not a dashboard.** A framed illustration, a serif place name and one
  headline fact. Everything else is quieter.
- **Truthfulness as a design material.** The app shows "Rising" only when it can defend it.
  Subordinate stations show stems at their published events, never a fake curve. The
  illustration's waterline moves only when NOAA publishes a height. Stale data is labeled.
- **The timeline is the app.** Dragging across the day moves a rust marker, updates the
  readout and raises or lowers the illustration's water, with a soft haptic at each real
  extreme.

## Visual directions considered
Three directions were weighed in sketches and notes. Only the chosen one was built, so
there are no screenshots of the others.
1. **Instrument panel:** gauges, a dial and dense tables. Rejected: it is a dashboard, the
   thing to avoid.
2. **Photographic postcard:** a full-bleed photo per region. It was preferred for mood, but
   blocked for V1 because licensable, truthfully regional photography needs per-image
   provenance work and owner approval to download.
3. **Quiet Coastal Editorial with original illustration (chosen):** limestone paper, ink,
   sea-glass, New York serif with SF, and procedurally drawn coasts in six regional
   characters. It is legally clean, renders identically in widgets, adapts to dark mode and
   redraws as line art for tinted and clear Home Screens. It also lets the art *respond to
   the data*, which no stock photo can.

## Art system
- Palette tokens with light and dark values (`TideUI/Palette.swift`).
- Six `CoastRegion` scenes. Each is built from sky, far land, sea marks, a fixed beach slope
  and objects in the shallows. The waterline sits between fixed bounds and is driven by the
  normalized predicted height, so low water exposes rocks and pilings and high water covers
  them. Each scene has a painted variant and a single-colour line variant.
- An original mark (horizon plus tide line) used in the app, onboarding and icon.

## Tide data engineering
Highlights (see `Documentation/DATA.md`):
- Live probing found that NOAA's local-time output skips DST for some Alaska stations and
  that some metadata offsets are wrong. Little Tide therefore fetches GMT and resolves a
  civil IANA zone itself.
- It requests the 15-minute curve only from reference stations and degrades honestly to
  high/low-only when the curve is missing.
- A pure, clock-injected `TideEngine` drives all of this, with 72 unit tests covering DST,
  midnight, year boundaries, uneven event counts, gaps, negatives and malformed data.
- Against NOAA's own published tables, 5 stations matched every event to the minute.

## Widget implementation
- Pure `CoastWidgetContent` per timeline entry, with family-specific compositions.
- Entries every 30 minutes plus one second after each event, reloading at the earlier of
  6 h or the last known event.
- Line art and system colours when `widgetRenderingMode` is not full colour.
- Verified by automating SpringBoard: install both sizes, deep-link back into the app, and
  capture light, dark, tinted and clear styles.

## Test evidence
- 87 automated tests: 84 passed and 3 skipped by design (opt-in Home Screen and live NOAA).
- Screenshots are in `Documentation/Screenshots/{app,widgets,qa}` and demo clips in
  `Documentation/Media`.

## Launch decisions
- Free, with one coast, both widgets and the full timeline.
- "Plus" (favourites, extra compositions, personal photos) was deferred rather than shipped
  as an inert paywall.
- US NOAA stations only, iPhone only, no location permission.

## Honest limitations
- Illustrations only for now; photography is pending licensing.
- One coast at a time, and widgets follow it. There is no per-widget station.
- Catalog stations without a NOAA state field were assigned by name or a 20 km
  nearest-neighbour rule and spot-checked; a few edge cases may remain.
- Signing, device testing (haptics and VoiceOver on hardware), App Store Connect and naming
  checks are still to do.
- No usage metrics exist, by design. There is no analytics.
