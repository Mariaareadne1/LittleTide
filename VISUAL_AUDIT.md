# Visual audit: current build vs approved reference

Audited 2026-11-16 at `f5471ad` on `main`. Baseline: Xcode 26.6, iPhone 17 Pro (iOS 26.5).
95 tests: 92 passed, 0 failed, 3 skipped (opt-in). The side-by-side is
`Documentation/Design/reference/audit-reference-vs-current.png`. The reference is a
flattened 1402×1538 collage (`1.webp`), usable only as a visual target, not as art layers.

## Where things live
| Concern | Files |
|---|---|
| Main screen | `LittleTide/Features/CoastHome/CoastHomeView.swift` (scroll, sheets, status scrim), `CoastHero.swift` (art, header, identity, `TideCard`, `StatusBarScrim`), `CoastReadyView.swift` (card + study section + lists), `CoastComponents.swift` (`NowSummaryView`, `TrendBadge`, `DayEventsList`, `SourceFooter`, `FreshnessBanner`), `CoastStateView.swift` |
| Illustration | `Packages/TideKit/Sources/TideUI/Art/`: `CoastArtView.swift` (two `Canvas` layers), `CoastScene.swift` (unit-space paths), `CoastPainter.swift` (painters), `ArtPalette.swift`; region choice in `TideKit/Domain/CoastRegion.swift` |
| Glass | `TideUI/Glass.swift` (`glassSurface`: iOS 26 `glassEffect`, material fallback, opaque under Reduce Transparency; `GlassButtonStyle`) |
| Typography / layout tokens | `TideUI/Typography.swift` (`TypeStyle`), `BrandTypeface.swift` (Newsreader registration, variable axes), `Palette.swift` |
| Tide graph + scrub | `LittleTide/Features/TideTimeline/TideStudyView.swift` (Canvas, drag, haptics, VoiceOver adjustable), `TideReadout.swift`; geometry `TideUI/TideChartGeometry.swift` |
| Widgets | `LittleTideWidgets/LittleTideWidgetBundle.swift` (provider, entry view, `containerBackground`), `TideUI/CoastWidgetViews.swift` (cards, `CoastWidgetBackground`, `RhythmStrip`), `TideKit/Shared/CoastWidgetContent.swift`, `WidgetTimelinePlanner.swift` |
| NOAA + persistence + logic (tested) | `TideKit/Data/` (`NOAATideClient`, `NOAADecoder`, `NOAARequest`, `TideRepository`, `ForecastCache`, `StationCatalog`), `TideKit/TideEngine/`, `TideKit/Shared/SharedSettings.swift`, `SharedContainer.swift`; app state `LittleTide/App/AppModel.swift` |

## Gap analysis
| Aspect | Reference | Current | Verdict |
|---|---|---|---|
| Viewpoint | Overhead aerial coast: beach on a diagonal, water filling the frame | Side-on view with a horizon, sky taking 40% | Wrong. Needs a new scene model |
| Rendering | Painterly: brushy water texture, lacy foam networks, wet-sand gloss, lit rocks | ~40 vector paths plus sine strokes; flat fills | Can't reach the target. Replace |
| Palette | Saturated turquoise to deep teal across the whole screen; UI sits *on* water | Limestone paper with muted sea; UI on paper | Wrong |
| Typography | White serif title near the bottom over water; white SF secondary | Ink serif title at the top over sky | Restyle and recompose |
| Glass | Teal-tinted, refractive, white text, soft rim | Milky paper-tinted glass (introduced for contrast) | Retint; contrast via tint and scrim |
| Composition | Art dominates the full screen; the card sits low; controls float | Art ~60% of the first screen; paper below | Recompose |
| Timeline | Teal surface; painted water fills under the curve | Paper surface; flat gradient fill | Restyle and reuse the art as the fill |
| Widgets | Aerial water scenes, white type | Side-view art with a paper veil | Rebuild compositions |
| Data in reference | "Nauset Beach · Station 8449920" | — | **8449920 is not a NOAA tide-prediction station.** The truthful equivalent is 8447435, Chatham Harbor (Aunt Lydias Cove), beside Nauset on Cape Cod |
| Reference features | Today/Week/Month tabs; sun, moon and layers buttons; people, turtles, boat | — | Not V1 functionality. Moon calendars are explicitly out of scope; no decorative non-working controls will be added |

## Decision
Replace the vector illustration with a **layered, height-field illustration system**:
- **Offline:** a deterministic generator renders original painterly layers per scene: dry
  land (sand, dunes, rocks), water colour, a height map, foam lace, and precomputed widget
  composites.
- **In the app:** a Metal shader composites the layers, with the waterline set by the
  normalized predicted level. Foam and caustics drift subtly unless Reduce Motion is on.
- **Widgets:** precomputed snapshots at discrete tide levels, chosen per timeline entry.

The waterline is illustrative and is labelled as such.

## Milestone 1 result: East Coast scene (2026-11-16)
- **ArtForge** (`Packages/TideKit/Sources/ArtForge/`): a deterministic offline generator with
  no dependencies, about 3 s per scene.
  - It designs a height field: a sandy point, offshore sandbars, glacial boulders and dunes.
  - From that it paints original layers: `land.jpg` (sand, relief-shaded dunes, grass, lit
    boulders, built from thousands of brush strokes); `water.jpg` (soft-posterised depth
    bands with contour-following strokes); and `data.png` (R height, G foam bubble-lace,
    B foam wander).
  - It also writes widget snapshots at five tide levels.
- **In the app:** a Metal stitchable shader (`TideUI/Shaders/TideScene.metal`) composites a
  single three-panel atlas (SwiftUI shaders take one image) at the normalised predicted level:
  - dry sand, wet-sand darkening, the seabed seen through turquoise shallows, and deep water;
  - three wandering surf ribbons with bubble-holed edges, gated to shallow water;
  - with motion allowed, a ±0.004 swash and slow foam drift (off under Reduce Motion).
  - The waterline is illustrative.
- **Composition:** the full-screen painted coast, glass header buttons, a white SF region
  label and white serif place name over a teal scrim, and a teal Liquid Glass tide card.
  Details sit below on ocean teal: a painted-water fill under NOAA's curve, glass panels for
  highs/lows and source.
- Evidence: `Documentation/Design/reconstruction/m1-*.png|jpg`, comparing the reference, the
  live app (Chatham 8447435, real NOAA data) and the generator's high-tide state.
- **Remaining differences:**
  - The reference shows people and more chaotic swirling foam. People are omitted by design.
  - Foam here comes from terrain physics, not freehand painting.
- **Open:** regions without a painted scene yet still use the old illustration, and white
  type on its pale sky fails contrast (measured 2.1–4.4:1). Painted NorCal and SoCal scenes
  in milestone 2 replace it.
