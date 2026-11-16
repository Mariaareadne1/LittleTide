# Tide data: sources, rules and verification

## Sources
- **Predictions:** NOAA CO-OPS Data API, `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter`,
  `product=predictions&datum=MLLW&units=metric&time_zone=gmt&format=json&application=LittleTide_iOS`,
  `begin_date=<now−36 h, hour-aligned> & range=204` (hours).
  - `interval=hilo`: always requested. These are the published high and low events.
  - `interval=15`: requested only for reference (`R`) stations. If NOAA rejects it, the
    forecast is high/low-only and says so. Subordinate (`S`) stations are never asked.
- **Stations:** CO-OPS Metadata API `stations.json?type=tidepredictions`, bundled as
  `TideKit/Resources/stations.json` (generated 2026-11-16, 3,228 stations: 1,234 R, 1,994 S).

## Catalog rules (`CatalogBuilder`)
- Keep stations whose NOAA `state` is a supported US state or territory: the coastal states,
  DC, AK, HI, PR, VI and GU. Freely associated states and foreign stations (Canada, Fiji, Samoa,
  Palau, Micronesia, Bermuda, …) are excluded.
- Stations listed with no state get one from a state abbreviation in their name ("Oreg.",
  "Wash.", …). Failing that, they take the state of a supported-state station within 20 km.
  Canadian names and NOAA's Canadian `82xxxxx` IDs are excluded. 160 stations were assigned
  this way and spot-checked.

## Time zones
NOAA metadata carries only a standard offset (`timezonecorr`), and NOAA's `lst_ldt` output
does not follow civil time everywhere. This was verified live on 2026-11-16 by matching
`gmt` and `lst_ldt` events across the 8 Mar 2026 DST change:
- Eastern, Central, Pacific and Alaska (−9) stations follow US DST in `lst_ldt`.
- Alaska stations tagged −10/−11 (e.g. Port Nellie Juan, St. George Island) are published
  with no DST, although they keep Alaska civil time.
- Some offsets are wrong, e.g. Indian Rocks Beach FL is tagged −6 but sits in Eastern
  Pinellas County, and Sabine Pass TX is tagged −5 but is in Central time.

Little Tide therefore fetches **GMT** and displays each station's **civil IANA zone**
(`StationTimeZoneResolver`):
- Florida splits at 85.4° W.
- The Aleutians west of 169.5° W and south of 55.5° N use `America/Adak`.
- The Pribilofs use `America/Anchorage`.
- Hawaii uses `Pacific/Honolulu`, PR/VI use `America/Puerto_Rico` and Guam uses `Pacific/Guam`.

Where NOAA's own local-time table disagrees with civil time, Little Tide's times follow the
phone clock a person at that station would see, and the absolute instant is identical.

## Engine guarantees (`TideEngine`, all unit-tested)
- The next event is the first one strictly after the instant, at an exact high, the following low.
- The direction (rising/falling) comes from the sample slope when there is a curve. Otherwise
  it comes from bracketing events of opposite kinds no more than 16 h apart. In every other
  case it is **unknown** and hidden.
- Heights come from exact events (±60 s) or linear interpolation between two adjacent NOAA
  samples at most 60 min apart. Nothing is extrapolated or synthesised from events.
- Freshness: *current*; *aging* (more than 12 h old, labelled "Last updated"); *expired* (no
  known next event), which shows "Forecast unavailable".
- Network: 20 s timeout and two retries (2 s, 6 s) for timeouts, 5xx and throttling
  (403/429). Requests are deduplicated per station. Automatic refresh happens at most every
  3 h, or sooner if the forecast reaches less than 3 days ahead. Manual refresh is limited to
  once a minute. Scrubbing never touches the network.

## Verification against NOAA's published predictions
`LiveNOAAComparisonTests` (run 2026-11-16, `Documentation/Evidence/noaa-live-comparison.txt`)
fetched each station through Little Tide's pipeline and compared it with NOAA's own
`lst_ldt` / English-unit table for the same station-local date. Every event matched to the
minute, and heights agreed within 0.001 ft:

| Station | Type | Zone | Events |
|---|---|---|---|
| 9410840 Santa Monica, CA | R | America/Los_Angeles | 4/4 |
| 8413320 Bar Harbor, ME | R | America/New_York | 4/4 |
| 1612340 Honolulu, HI | R | Pacific/Honolulu | 4/4 |
| 8724580 Key West, FL | R | America/New_York | 4/4 |
| 8510502 Montauk Harbor entrance, NY | S | America/New_York | 4/4 |

The live widget on the simulator Home Screen also showed *Low 9:13 PM, 0.8 ft* for Santa
Monica, against NOAA's 21:13 at 0.798 ft.

## Datum
Heights are metres above **MLLW** (Mean Lower Low Water), shown in feet or metres.
They are not water depth, and negative values are valid.
