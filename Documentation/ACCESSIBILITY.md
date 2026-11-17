# Accessibility

## Implemented
- **VoiceOver.** Explicit labels such as "High tide at 1:04 PM, predicted height 4.1 feet.";
  the Now summary is read as one element in order. The tide study is an *adjustable* element:
  swiping up or down moves 15 minutes, or to the next published event on high/low-only
  stations, and the readout is spoken. Highs and lows are also listed as buttons. The
  illustration is announced as "Illustration … Representative, not a live view."
- **Dynamic Type.** System text styles throughout. Long names wrap to three lines, then scale
  to at least 70%. The illustration caption wraps. Checked at Accessibility-L on the iPhone 17e.
- **Non-colour cues.** Rising and falling use an arrow plus a word. Highs and lows use "H"/"L"
  labels and arrows. The selection uses a vertical rule plus a readout, not colour alone.
- **Reduce Motion.** The illustration's waterline animation is disabled.
- **Haptics.** A single soft impact only when scrubbing crosses a real predicted extreme.
  It can be turned off in Settings.
- **Widgets.** Each widget is one combined element with a full spoken sentence. Tinted and
  clear modes use line art and system colours.

## Contrast (WCAG 2.x, computed from the palette tokens)
| Pair | Light | Dark |
|---|---|---|
| ink / paper | 10.91:1 | 14.05:1 |
| inkSoft / paper | 7.28:1 | 9.86:1 |
| seaGlassDeep / paper | 5.75:1 | 9.75:1 |
| rust / paper | 5.02:1 | 6.35:1 |
| inkSoft / fog | 6.53:1 | 8.55:1 |

## Automated audit
`AccessibilityAuditTests` runs `XCUIApplication.performAccessibilityAudit()` on onboarding,
search, home with a curve (top and scrolled) and a high/low-only home.

Fixed because of the audit:
- the system-grey section headers failed contrast;
- the non-interactive trend badge was exposed as a small separate element;
- the onboarding caption used a fixed small style.

Documented exclusions:
- `textClipped`: fires where the spoken label is intentionally richer than the visible text.
  Truncation is checked visually instead.
- System search field and Close button.
- Text drawn inside the chart Canvas, which is exposed through the adjustable value.
- Two contrast reports on `Palette.ink` text, "Featured coasts" and "Rising". The auditor
  sampled over neighbouring surfaces, and the measured ratio is 10.9:1.

## After the typography and glass redesign (2026-11-16)
- Text on painted art or glass is always full `ink`, never `inkSoft`. The tide card and
  onboarding card use a milky, paper-tinted glass, and the region label sits on its own
  glass pill.
- Reduce Transparency: every glass surface becomes opaque paper with a sand hairline.
  Verified on the simulator (`Documentation/Design/after/reduce-transparency.png`).
- Reduce Motion: the waterline, button-press and station-change animations are disabled.
- Dynamic Type:
  - SF styles use native text styles.
  - Serif styles are built through `UIFontMetrics.scaledFont`, with an optical size
    matched to the scaled size.
  - Rows reflow with `ViewThatFits` at large sizes.
  - The wordmark and header controls cap at xxxLarge so content keeps the room.
- The audit's contrast sampler misreads text over painted and glass backgrounds. The test
  now **measures each flagged element's rendered pixels** (darkest 3 % against the 60th
  percentile) and fails anything under 4.5:1. Measured: wordmark 8.8:1, region pill
  10.9:1, onboarding title 10.5:1, onboarding body 10.6:1.
- Remaining exclusions:
  - Dynamic Type reports on `ViewThatFits` rows and the capped wordmark.
  - Element-less contrast reports from the system sheet's glass navigation chrome.
  - Contrast reports for text less than half on screen: under the status bar and its
    frosted scrim (status bar + 30 pt), or past the bottom edge after the audit scrolls.
    Those elements are intentionally occluded or have no pixels to measure.
  - Dynamic Type reports on the tide card header ("Rising tide", "Predicted · NOAA") and the
    highs-and-lows rows ("High tide", "Low tide"), which reflow from one row to two with
    `ViewThatFits`; verified growing at AX-XXL on iPhone 17
    Pro and iPhone SE (`Design/refinement/r6-accessibility-xxl.jpg`).

## Painted scenes and shader glass (2026-11-17)
- White type over painted water sits on deep-teal shader glass, with scrims and a
  deep-teal halo.
- The onboarding "Original illustration" pill measured 4.53–4.66:1. That was too close to
  4.5:1 while the water animates behind it, so it gained a tight halo.

## Not yet verified
On-device VoiceOver, haptics and Switch Control. The simulator has no haptics, and VoiceOver
was checked through the accessibility tree rather than by listening.
