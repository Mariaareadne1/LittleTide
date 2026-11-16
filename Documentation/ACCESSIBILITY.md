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

## Not yet verified
On-device VoiceOver, haptics and Switch Control. The simulator has no haptics, and VoiceOver
was checked through the accessibility tree rather than by listening.
