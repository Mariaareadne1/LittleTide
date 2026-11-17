# Product refinement

Answers to "would a stranger install this and keep it?", using what the app does now.

| Question | Answer and evidence |
|---|---|
| Understandable in five seconds? | Yes. The first screen is a painted coast, the place name and "Rising tide · High at 1:04 PM". Onboarding is one card: "A little window into your coast." |
| Main purpose visible without explanation? | The next high or low leads every surface: hero card, widgets, Lock Screen faces. |
| Genuinely useful? | Next event with countdown, direction, height and station time; the full day's curve; seven days of paging; offline from dated cache. Predictions only, labelled as such. |
| Widget beautiful at real size? | Verified on the simulator Home Screen with live NOAA data (`Design/refinement/r5-home-screen-widgets-live.jpg`). Tinted and clear fall back to line art. |
| Easy to choose a beach? | Search by town, bay, state or ID; featured coasts; browse by state. Honest about stations being harbors and piers, not beaches. |
| Too much configuration? | One choice (a coast). Units and haptics are optional. |
| Value without an account? | Everything is free; no account, ads or tracking. |
| Reason to return tomorrow? | The tide changes daily; widgets and Lock Screen faces make it glanceable; recent coasts make switching between home and a holiday beach one tap. |
| More distinctive than a tide widget? | The painted coast and coast window show the water moving with the prediction; glass bends the painting. Competitors with strong tables (Tide Guide) and free privacy (Ocean Watch) exist, so distinctiveness rests on the visual system, not on being free or private (`COMPETITORS.md`). |
| Does the visual system help understanding? | The coast window turns "0.8 ft at 9:13 PM" into wide wet sand; VoiceOver reads the same as "Water near the day's low". |

## Shipped in this refinement (V1 scope)
- Recent coasts (up to four) and a clear "Showing" state in the picker.
- Lock Screen widgets: inline, circular gauge, rectangular.
- Staleness inside the tide card on the first screen.
- Coast window that follows the scrubbed tide.
- Large-text layouts that never truncate the tide time; iPhone SE verified.

## Deliberately not in V1
Observed water levels, weather, surf, sun and moon, location permission, accounts,
per-widget station choice, Live Activities, Watch. Candidates for later, in rough order of
value: sunrise/sunset marks on the curve, a configurable widget station (App Intents),
observed levels clearly separated from predictions.

## Pricing recommendation
Ship V1 free with everything above; do not add a paywall without new value. A later
"Plus" could carry per-widget coasts, extra scenes and a sunrise layer as a one-time
purchase (competitors charge $18–30 a year; a calm single-coast app is better served by a
small one-time price than a subscription). Not implemented: no StoreKit code ships.
