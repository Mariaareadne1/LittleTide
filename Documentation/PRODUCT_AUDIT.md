# Product audit (baseline d9c9064, 2026-11-17)

Scores are 1–5 against a shipped consumer-app bar, with the evidence that set them.
Screenshots: `Documentation/Baseline/Screenshots/`.

| Category | Score | Evidence |
|---|---|---|
| Product clarity | 4 | Onboarding states the purpose in one line; home leads with "Rising tide · High at 1:04 PM". "Little window into your coast" reads as a tide app only with the body copy. |
| First-run experience | 4 | `testFirstLaunchSearchAndChooseCoast`: featured coasts, search, browse by state; no account or permission. Search results explain stations are harbors/piers, not beaches. |
| Daily usefulness | 3 | Next event, curve, day list, units. Only one coast; no Lock Screen widget; no recents. Competitors all offer favorites (`COMPETITORS.md`). |
| Visual identity | 4 | Painted aerial coast, deep-teal shader glass, Newsreader serif. Sheets (search, settings) fall back to plain cream system lists and feel like a different app. |
| Composition | 3 | Hero is strong; scrolled title slides under the status bar (`11-home-scrubbed`); details stack is a long column of similar glass panels. |
| Typography | 4 | Coherent serif/SF pairing, tabular data, Dynamic Type via `UIFontMetrics`. Small 12–13 pt labels over art sit near contrast limits. |
| Material quality | 4 | In-shader refraction, Fresnel, aberration (glass-studies port). Underwater backdrop behind details is flatter than the hero. |
| Interaction | 4 | Scrub, snap for hi/lo stations, Now, day pager, haptics. Hero waterline uses today's range on other days (clipping risk). |
| Data accuracy | 5 | NOAA-only, GMT→station zone, no invented curve, prediction labels, live comparison test. Fixture gap: Atlantic/Gulf/Alaska. |
| Widgets | 4 | Small/medium, painted snapshots, accented/tinted handled, deep link. No Lock Screen family. |
| Accessibility | 4 | VoiceOver labels on readouts, Reduce Motion/Transparency, measured-contrast audits pass. Small-device and largest-type screenshots not re-captured since the painted redesign. |
| Performance | 2 | Not measured. Full-screen Metal shader animates via `TimelineView` (paused only under Reduce Motion), likely also while scrolled away. |
| Reliability | 4 | Offline/aging/expired/failure states tested. Staleness cue is below the fold (`30-offline-cached`). |
| App Store readiness | 3 | Privacy manifest, OFL, public privacy/support URLs, 0-warning archive. Blocked on owner: team ID, signing, App Group, name, support email. |
| Portfolio value | 4 | Clear design + engineering story; case study exists but predates the painted/glass work. |

## Five most important weaknesses (ranked by user impact, visual impact, risk, effort)
1. **Staleness is invisible on the first screen.** Offline/aging status lives in a banner
   below the hero. Trust issue; small effort. → show freshness inside the tide card.
2. **Rendering cost unmeasured; the shader animates continuously.** Battery/thermal risk on
   device; medium effort. → pause when the scene is off-screen or the app inactive; measure.
3. **One coast only.** Daily-use gap every competitor fills; small effort. → recent coasts
   (last five) in the coast picker, no new storage model beyond an ID list.
4. **Scrolled header collides with the status bar; hero level on other days clips.**
   Visible polish/data-visual mismatch; small effort. → fix scrim timing; use the window's
   range.
5. **No Lock Screen widget.** Widget-first product missing the most glanced surface;
   medium effort. → accessory inline/circular/rectangular families from existing content.

Deferred (not V1): sunrise/sunset marks, multi-day list view, observed water levels,
location permission.
