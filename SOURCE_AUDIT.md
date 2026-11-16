# Source audit

Inspected 2026-11-16, read-only, from shallow clones in a temporary directory.
**No source code from any of these repositories was copied into Little Tide.** All
code in this repository is original. The references informed structure and checks only.

| Repository | Commit inspected | License | Used for |
|---|---|---|---|
| pawello2222/WidgetExamples | `3597d22` | MIT | Patterns only: App Group sharing via suite defaults/container, `widgetURL` + `onOpenURL` deep links, `.after(date)` reload policy, `containerBackground`. |
| konotori/iOSAppTemplate | `c396914` | MIT | Evaluated and **not adopted** (see below). |
| twostraws/swiftui-agent-skill | `f2920b6` | MIT | Modern SwiftUI checklist applied during review. |
| dpearson2699/swift-ios-skills | `8d90fd1` | PolyForm Perimeter 1.0.0 | Read as reference only; nothing redistributed or adapted. |

## Findings

**WidgetExamples.** iOS 17 deployment target; one folder per example under `Widgets/`.
`Widgets/AnalogClockWidget/` relies on a private-API binary
(`Frameworks/ClockRotationEffect.xcframework`) — **excluded**, as required. Relevant
public-API patterns: `Shared/Extensions/UserDefaults+Extensions.swift` (suite defaults),
`Shared/Extensions/FileManager+Extensions.swift` (group container),
`Widgets/DeepLinkWidget/*` + `App/Navigation/DeepLink+Parser.swift` (deep links),
`Widgets/LockScreenWidget/LockScreenWidget+Provider.swift` (`.after` policy). It has no
`widgetRenderingMode`/accented examples, so tinted/clear handling follows Apple's
WidgetKit documentation instead.

**iOSAppTemplate.** Five-layer Clean Architecture with mostly placeholder folders, three
third-party SPM packages (LogPipe, NaviStack, RESTKit), three build environments, Mint,
Periphery and an `npx`-based MCP config. Excessive for a ~40-file app with a no-external-
dependency rule, so not adopted. Little Tide uses a local Swift package for testable
logic plus thin feature folders.

**swiftui-agent-skill.** Markdown only (`swiftui-pro/SKILL.md`, `references/*.md`); no
executable scripts, so nothing was installed or run. Rules applied: `@Observable` +
`@MainActor` view models owned with `@State`; `NavigationStack`; `foregroundStyle`;
two-parameter `onChange`; `FormatStyle` instead of `String(format:)` in UI code;
async/await with `Task.sleep(for:)`; strict concurrency.

**swift-ios-skills.** PolyForm Perimeter is a non-compete licence with a required-notice
clause, so it was treated as reading material only. Points checked against Apple's own
documentation before relying on them: `AppIntentTimelineProvider`/App Group sharing,
synchronous `placeholder`, one `widgetURL` per widget, `widgetRenderingMode` +
`widgetAccentable` for tinted/clear modes, `PrivacyInfo.xcprivacy` declaring the
UserDefaults required-reason API in both app and extension, App Review 2.1/2.3/4.2/5.1.

Required notice (reproduced because the repository was read): *Copyright (c) 2025
dpearson2699 (https://github.com/dpearson2699)*.

## Other projects

Filo, Meadow and Sky Study (separate web projects in the parent folder) were **not**
inspected or reused; nothing from them is portable to a native widget.

## Official sources consulted

- NOAA CO-OPS Data API (`api/prod`) and Metadata API (`mdapi/prod`), verified with live
  requests; captured responses are the test fixtures in
  `Packages/TideKit/Tests/TideKitTests/Fixtures`.
- Apple WidgetKit, App Intents and App Review Guidelines (see `Documentation/APP_STORE.md`).
