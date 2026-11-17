# Typography

## Faces actually used
| Role | Face | Source | Licence | Shipped |
|---|---|---|---|---|
| Editorial serif: wordmark, place names, headline tide times, section headings, event titles, widget hero | **Newsreader** (variable: weight 200–800, optical size 6–72), roman and italic | Production Type, via `github.com/google/fonts/ofl/newsreader`, downloaded 2026-11-16 (`Newsreader[opsz,wght].ttf`, 451,664 bytes, sha256 `8a08d13f…`; `Newsreader-Italic[opsz,wght].ttf`, 495,684 bytes, sha256 `796668…`) | SIL Open Font License 1.1. Embedding in apps is permitted; the licence text ships as `Fonts/OFL.txt` inside the bundle | Yes, in TideUI's resources, used by the app and the widget |
| Functional: controls, times, heights, IDs, metadata, settings | **SF Pro** (system) | Apple | Apple system font, not bundled | System |

**Canela is not used and not bundled.** It is a Commercial Type font and needs a mobile-app
licence. No licensed files were provided, and none were sought from unofficial sources.
Newsreader is the documented stand-in. It is not presented as Canela anywhere.

### Switching to licensed Canela later
1. Buy a Commercial Type **mobile application** licence covering the app and widget extension.
2. Add the licensed files to `Packages/TideKit/Sources/TideUI/Fonts/` and list them in
   `BrandTypeface.canela.fileNames`.
3. Set the PostScript names in `BrandTypeface.postScriptNames`.
4. Set `BrandTypeface.current = .canela`.

Canela isn't variable, so styles use its static cuts and the weight values in `TypeStyle`
are ignored. Check the Deck/Text cuts against the display and text roles. No view code changes.

## System
All text uses `.typeStyle(_:)` with a semantic `TypeStyle`, never ad-hoc `.font()`.

| Style | Face | Size at Large | Notes |
|---|---|---|---|
| brand | serif 420 | 27 | wordmark; growth capped at xxxLarge |
| heroLocation | serif 360 | 40 | tracking −0.8; up to 4 lines |
| heroTideTime | serif 430 | 33 | tabular figures |
| sectionHeading | serif 380 *italic* | 25 | the only italic, e.g. "The tide today" |
| eventTitle | serif 420 | 20 | "High tide" / "Low tide" |
| widgetHeroSmall / Medium / widgetPlace | serif | 27 / 28 / 15 | fixed widget sizes |
| body / bodyEmphasis | SF subheadline | 15 | |
| data | SF callout medium | 16 | tabular |
| label | SF footnote semibold | 13 | |
| regionLabel | SF caption semibold, tracked 1.4, uppercase | 12 | |
| metadata | SF caption | 12 | tabular |
| chartLabel | SF caption2 medium | 11 | tabular |

How it works:
- Serif fonts are built through CoreText with an explicit weight, and an optical size equal
  to the rendered point size. `UIFontMetrics.scaledFont` then makes them follow Dynamic Type.
- SF styles use native text styles.
- `FontRegistry` registers the fonts in each process, app and widget extension alike.
- `TypographyTests` proves the serif loads as "Newsreader", that weight and optical-size
  variations apply, and that it scales.

## Comparison (real simulator screenshots, same stations, data and art)
- **Before:** Apple New York serif with SF, flat illustrations
  (`Documentation/Design/before/`).
- **After:** Newsreader with SF, painterly art and glass (`Documentation/Design/after/`).

Canela could not be compared because it isn't licensed.

Newsreader won over New York on several counts:
- It has softer, more calligraphic terminals and lower stroke contrast at display sizes,
  which is closer to Canela's warmth.
- Its true optical sizing keeps 11–15 pt widget text sturdy while 40 pt place names stay delicate.
- Its italic is expressive enough for the single editorial heading.

New York read more as a "system serif", and it doesn't give the brand a voice of its own.
