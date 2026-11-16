# App Store and TestFlight kit

Status at 2026-11-16: **TestFlight-ready code, not yet signed or uploaded.** This Mac has no
Apple Developer team or signing identity. Approval cannot be guaranteed; the notes below
follow the current App Review Guidelines as read during development.

## Owner-only steps, in order
1. **Apple Developer Program** membership. Set `DEVELOPMENT_TEAM` in `project.yml`
   (`settings.base`), then run `xcodegen generate`.
2. **Bundle IDs and App Group** in Certificates, Identifiers & Profiles. Placeholders in use:
   `app.littletide.LittleTide`, `app.littletide.LittleTide.Widgets`,
   `group.app.littletide.shared`. If you change them, update `project.yml`,
   `SharedContainer.appGroupIdentifier` and both `.entitlements` files to match.
3. **Name check.** Search App Store Connect for "Little Tide" and close variants. This was
   *not* verified. The name lives in `CFBundleDisplayName`, the widget display name and
   onboarding copy.
4. **Public URLs.** Host `Documentation/PRIVACY.md` and `Documentation/SUPPORT.md` publicly
   (e.g. GitHub Pages; the repository is private) and add a support email. Then update
   `LegalText.supportURL` in `LittleTide/Features/Settings/LegalText.swift`.
5. Create the app record, archive with your team (see README), upload and add TestFlight testers.
6. Complete App Privacy, age rating and export compliance with the answers below, then submit.

## Build facts
- Xcode 26.6 (17F113) and the iOS 26.5 SDK. This meets Apple's Xcode 26 / iOS 26 SDK
  upload requirement, in force since 28 Apr 2026; recheck on submission day.
- Deployment target iOS 17.0, iPhone only, portrait. Version 1.0, build 1.
- An unsigned Release archive builds; the DEBUG demo code and fixtures are excluded.
- `ITSAppUsesNonExemptEncryption = NO`: the app uses HTTPS only.
- Privacy manifests ship in the app and the widget. They declare the UserDefaults API with
  reason `1C8F.1` (App Group sharing), no tracking and no collected data.
- **StoreKit:** none. "Little Tide Plus" is deferred (see PROGRESS.md), so no purchase UI ships.

## App Privacy answers
- Data collection: **Data Not Collected**. No tracking.
- NOAA receives the station ID and date range, but the developer never collects them.
- No third-party SDKs.

## Age rating
No objectionable content, user-generated content, web browsing, gambling or medical
content. Expected **4+**.

## Listing copy (draft)
- **Name:** Little Tide
- **Subtitle candidates:** "Tide times for your coast" · "A window into your coast" · "NOAA tides, quietly"
- **Promotional text:** A small coastal almanac: the next high or low at your NOAA station, on your Home Screen.
- **Description:**
  > Little Tide is a quiet window into your coast. Choose one of more than 3,000 NOAA
  > tide-prediction stations across the United States and see the next predicted high or
  > low, in the station's own local time.
  >
  > • Small and medium Home Screen widgets that look at home in light, dark, tinted and clear styles.
  > • A day of tide you can explore with a finger, drawn from NOAA's 15-minute predictions where they exist.
  > • Honest data: subordinate stations show NOAA's published highs and lows, and nothing is guessed in between.
  > • Works offline from saved predictions, clearly dated.
  > • Original illustrations for each kind of coast.
  > • No account, ads, tracking or location.
  >
  > Predictions come from NOAA CO-OPS. They are astronomical predictions; weather can make
  > actual water levels differ. Not for navigation or safety. Little Tide is not affiliated
  > with NOAA.
- **Keywords (≤100 chars):** `tide,tides,tide times,high tide,low tide,NOAA,coast,beach,widget,tide chart,shore,ocean`
- **Category:** Weather (primary), Travel (secondary)

## Screenshots
Use **real** captures from the real app, at 6.9" (1320×2868) and 6.1" sizes. Workflow:
`Tools/shoot.sh <sim> curve out.png`, or run the `LittleTideUITests` attachments.
Candidates in `Documentation/Screenshots/`:
1. Home: Santa Monica with the curve (`app/10-home-curve.png`)
2. Scrubbing to the evening low (`app/11-home-scrubbed.png`)
3. Widgets on the Home Screen, light (`widgets/home-light.png`)
4. Widgets in tinted mode (`widgets/home-tinted.png`)
5. A high/low-only station (`app/20-home-highlow.png`)
6. Search and featured coasts (`app/02-search-featured.png`)

Demo-mode screenshots use real NOAA predictions captured on 15–18 Nov 2026 with a fixed
clock. The caption should say "NOAA predictions". Never describe them as a "live beach camera".
Don't use the `qa/*layouttest*` images, which put fixture data under other station names.
Suggested alt text: "Little Tide showing Santa Monica's predicted high at 1:04 PM and a
curve of the day's tide."

## Demo recordings (`Documentation/Media/`)
- **demo-a-widget-to-app.mp4.** Script: Home Screen with both widgets; tap the medium widget;
  the app opens on Santa Monica with live NOAA data.
- **demo-b-scrub-tide.mp4.** Script: drag across the day to the evening low; the marker,
  readout and illustration's waterline follow; tap **Now**. This uses captured NOAA data and
  a fixed clock.
- **demo-c-choose-coast.mp4.** Script: first launch, **Choose your coast**, an honest
  no-match search, then search "santa monica" and pick the station.

## Reviewer notes (paste into App Review Information)
> Little Tide shows NOAA CO-OPS tide predictions. No login is required. On first launch, tap
> "Choose your coast" and pick any featured station, e.g. Santa Monica. Drag across "The tide
> today" to explore it. Add a widget from the Home Screen (Edit → Add Widget → Little Tide).
> The app needs network access the first time; afterwards it works offline from saved
> predictions. No purchases, accounts or tracking.

## Guideline self-check
- **2.1 completeness:** every control works; there are no placeholders.
- **2.3 metadata:** claims match the features.
- **4.2 minimum functionality:** native widgets, an interactive timeline and search across 3,228 stations.
- **5.1.1 privacy:** a policy exists and is linked in-app; it must be hosted publicly (step 4).
- **2.5.1:** public APIs only.
- **5.2 IP:** original art, NOAA credited and not implied as an endorser.
