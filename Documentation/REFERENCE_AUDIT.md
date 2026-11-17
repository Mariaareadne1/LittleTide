# Reference audit (2026-11-17)

Read-only review of the references named in the refinement brief. Nothing was installed or
copied into Little Tide. Licences come from the GitHub API and each repo's LICENSE file.
Earlier source decisions are in `SOURCE_AUDIT.md`.

| Reference | What it is | Licence | Verdict | Why |
|---|---|---|---|---|
| pawello2222/WidgetExamples | ~20 WidgetKit demos | MIT | Reference only | Patterns already used (App Group defaults, `widgetURL`, `reloadTimelines`). Shows no tinted/accented rendering. |
| konotori/iOSAppTemplate | Clean-architecture starter | MIT | Reject | Too heavy for a ~40-file app; would replace, not refine. |
| Expo widgets + expo/examples `with-widgets` | JSX widgets on Expo | MIT | Reject | Little Tide is native SwiftUI; no Expo/React Native layer exists. |
| amosgyamfi/open-swiftui-animations | SwiftUI motion gallery | Unlicense per API (no LICENSE file found) | Reference only | Springs/loading ideas; no shader or widget content. |
| naughtyduk/liquidGL | WebGPU/WebGL glass over a DOM snapshot | MIT for scripts/package; assets excluded | Reference only | Web-only. Feature list (tint, aberration, bevel, specular) matches what the shader already does. |
| archisvaze/liquid-glass | WebGL + SVG glass | MIT | Reference only | Closest optical match: SDF rounded rect, bezel height profile, Snell refraction with IOR. Its demo IOR 3.0 is stylised; Little Tide keeps 1.52 (crown glass). |
| nordify/css-liquid-glass | `backdrop-filter` + SVG displacement | MIT | Reference only | Its rule "only one layer displaces; edge layers change exposure" matches the shader, where only refraction moves pixels and rim/glint/sheen add light. |
| wiiiimm/glass-gl | WebGL glass engine | AGPL-3.0 | Reject | Copyleft and web-only. Idea only: normal-driven rim light (already present). |
| rafael-b-g/PaperShaders | Two SwiftUI Metal stitchable shaders | MIT | Pattern confirmed | Same architecture as `TideScene.metal`: `[[stitchable]]` + `ShaderLibrary.bundle(.module)` from a SwiftPM resource bundle. |
| twostraws/swiftui-agent-skill | SwiftUI review skill | MIT | Applied earlier | See `SOURCE_AUDIT.md`. |
| dpearson2699/swift-ios-skills | iOS agent skills | PolyForm Perimeter 1.0.0 | Reference only | Licence restricts reuse. Relevant topics: WidgetKit accented rendering, App Store review, accessibility, performance. |
| mcs-cli/ios | `mcs` pack wiring MobileBuildMCP | No LICENSE at root (README claims MIT, unverified) | Reject | Needs extra tooling installed; unclear licence. Official `xcodebuild`/`simctl` already cover build, launch, screenshots, logs. |
| Maestro | YAML E2E runner | Apache-2.0 | Reject for now | Duplicates XCUITest and has no `performAccessibilityAudit` equivalent; nothing documented for widgets. |

## Takeaways applied
1. Widgets read `widgetRenderingMode`; key elements are marked `.widgetAccentable()` and are
   checked in full-color, accented (tinted) and clear on the real Home Screen.
2. Reload policy stays `.after(nextEventDate)` plus `reloadTimelines` after the app writes
   new predictions (WidgetExamples mostly uses `.never` + app reloads).
3. XCUITest + measured-contrast audits remain the E2E layer.
