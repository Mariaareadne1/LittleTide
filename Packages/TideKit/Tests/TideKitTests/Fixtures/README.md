# NOAA fixtures

Real responses from the NOAA CO-OPS Data API, saved verbatim. Never edit values by hand;
re-record instead. Base URL for predictions:
`https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=LittleTide_iOS&datum=MLLW&units=metric&time_zone=gmt&format=json`

| File | Station | Extra parameters | Recorded |
|---|---|---|---|
| `santamonica_9410840_hilo.json`, `_15min.json`, `_range48_hilo.json` | Santa Monica, CA (reference, Pacific) | see `NOAARequest` | 2026-11-16 |
| `kingharbor_9410738_hilo.json`, `_15min_error.json` | King Harbor, CA (subordinate) | `interval=hilo` / `15` (rejected) | 2026-11-16 |
| `frenchfrigate_1619222_hilo.json` | French Frigate Shoals, HI | `interval=hilo` | 2026-11-16 |
| `chatham_8447435_dst_hilo.json`, `_dst_15min.json` | Chatham, MA (Atlantic) | `begin_date=20261031 00:00&range=72&interval=hilo` / `15` | 2026-11-17 |
| `pensacola_8729840_hilo.json` | Pensacola, FL (Gulf, diurnal) | `begin_date=20261116 00:00&range=72&interval=hilo` | 2026-11-17 |
| `juneau_9452210_hilo.json`, `_15min.json` | Juneau, AK | `begin_date=20261116 00:00&range=48&interval=hilo` / `15` | 2026-11-17 |
| `error_bad_station.json`, `error_bad_date.json`, `error_throttled_403.json`, `empty_predictions.json`, `malformed_value.json` | error and edge cases | — | 2026-11-16 |
