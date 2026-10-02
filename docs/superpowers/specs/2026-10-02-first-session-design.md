# Lantern Keeper — first build session (CLAUDE.md steps 1–8)

## Context
The repo holds only `README.md` and `CLAUDE.md`. No code and no git. Goal: produce the first working native build. That covers the XcodeGen project, the tested domain, the design system, an accessible Harbour screen, and the full watch flow (setup → face-down prompt → active → completion/interruption). Lighthouse motion comes last, with a designed Reduce Motion state. Each step must build and pass tests before the next starts, and gets its own git commit.

Toolchain confirmed: XcodeGen at `/opt/homebrew/bin`, Xcode 26.6, `iPhone 17 Pro` simulator (iOS 26.5). Deployment target stays iOS 17.0.

### Decisions from the user
- Scope: CLAUDE.md first-session steps 1–8 only. Onboarding, full morning log, logbook and settings come in a later session.
- Git: `git init` first, then one commit per verified step.
- Snapshots: a small in-house helper using `ImageRenderer` and pixel compare. No packages.
- Bundle ID: `com.example.lanternkeeper`, no team, simulator only.
- Art: the teaser's flat silhouette (tower on rock, wave lines, beam, ship) recoloured to the CLAUDE.md palette. Tower bands use horizon/mist, never red.
- Services: real CoreMotion face-down detection, optional notifications and CoreHaptics, each behind a protocol with fakes.
- Default watch: 8 hours, duration mode. End-time mode is one tap away.
- Appearance: always night (`.preferredColorScheme(.dark)`). The dawn palette appears only for the completed state, and there is no appearance setting.
- Where the docs conflict, CLAUDE.md wins. Reflections are `clear | steady | tired`, and skip is stored as nil.

## Step 0 — repo and spec
- `git init`, plus `.gitignore` covering `*.xcodeproj`, DerivedData, `xcuserdata` and `.DS_Store`. The generated project is not committed because `project.yml` is its source of truth.
- Copy this plan to `docs/superpowers/specs/2026-10-02-first-session-design.md` and commit.

## Step 1–2 — XcodeGen project and empty app
`project.yml`:
- Targets: `LanternKeeper` (app, iOS 17.0), `LanternKeeperTests` (unit, hosted), `LanternKeeperUITests`.
- Settings: `SWIFT_VERSION 5.0` (Swift 5 language mode on the 6.x compiler), `SWIFT_STRICT_CONCURRENCY: complete`, `GENERATE_INFOPLIST_FILE` with explicit keys.
- Info keys: `UILaunchScreen` → `UIColorName: LaunchBackground` (asset = exact `#06141D`), `NSMotionUsageDescription` (neutral copy), portrait iPhone only.
- `Resources/Assets.xcassets`: AppIcon placeholder and LaunchBackground colour.
- `SupportingFiles/PrivacyInfo.xcprivacy`: tracking false, no collected data types, UserDefaults required-reason `CA92.1`.
- Minimal `LanternKeeperApp` + `AppRootView` showing a night background.
- Run `xcodegen generate`, build, commit.

## Step 3 — domain and Clock
- `Models/WatchStatus.swift` and `Models/MorningReflection.swift`, exactly as CLAUDE.md specifies.
- `Models/WatchSession.swift`: a `@Model` with the specified fields only. Typed `status` and `reflection` computed properties.
  - `measuredDuration`: completed = `targetEndAt − startedAt`; interrupted = `endedAt − startedAt`; active = nil. No stored durations.
  - Completion stamps `endedAt = targetEndAt`, not the reconcile time, so a late app open doesn't inflate watch time.
- `Models/WatchPlan.swift` (pure domain type):
  - `.duration(TimeInterval)` adds the interval to an absolute date.
  - `.endTime(hour:minute:)` uses `Calendar.nextDate(matching:)` in the current time zone, which handles midnight and DST.
  - `validate(now:)` throws when the end time is not in the future.
- `Models/UserPreferences.swift`: last plan and haptics on/off, stored in UserDefaults behind a `PreferencesStore` protocol. The in-memory fake is used for tests.
- `Services/Clock.swift`: the `Clock` protocol, `SystemClock`, and a test `FixedClock` (lock-protected and settable, `@unchecked Sendable`).
- `Services/WatchStore.swift` (`@MainActor`, wraps a `ModelContext`):
  - `activeWatch()`
  - `begin(plan:) throws` reconciles first, rejects if one is still active, validates the dates, inserts and saves. If the save fails it rolls back and throws `.persistenceFailed`. A watch is never reported as started without a successful save.
  - `reconcile() -> ReconcileOutcome` is idempotent and only completes `active` records whose target has passed. If more than one active record is found (a corruption guard), older ones are marked interrupted.
  - `interrupt()` runs exactly once; `logbook()` returns entries newest first.
  - `updateReflection(_:note:)` touches no date fields.
  - `delete(_:)` and `deleteAll()`.
  - Errors: `endNotInFuture`, `activeWatchExists`, `notActive`, `persistenceFailed`.
- OSLog `Logger(subsystem:category: "lifecycle")` logs only messages like "active watch reconciled", with no ids or times.

## Step 4 — unit tests (in-memory `ModelConfiguration(isStoredInMemoryOnly:)` plus FixedClock)
Covers:
- start valid / reject past end / prevent two active
- restore active (new store instance on the same container)
- complete exactly once (reconcile twice → one completion, `endedAt == targetEndAt`)
- early end → interrupted with the correct duration
- midnight crossing
- DST spring-forward and fall-back using a fixed `TimeZone("Europe/London")` calendar (an 8 h duration stays 8 h absolute; a 7:00 end-time resolves correctly)
- deletion removes only the targeted entries
- reflection update leaves the duration unchanged
- notification denial leaves the watch usable (with the Step 7 fake)

## Step 5 — design system
- `Design/Palette.swift`: raw tokens (hex init) and semantic tokens: background, raisedBackground, primaryText, secondaryText, action, focusRing, completed (dawn), interrupted (mist, never red). Increased-contrast variants come from `@Environment(\.colorSchemeContrast)` at the feature boundary.
- `Design/TypeScale.swift`: Dynamic Type only.
  - wordmark/morning headings: `.system(.largeTitle, design: .serif)` (New York)
  - UI: `.system(.body)`
  - times: `.system(.title, design: .monospaced).monospacedDigit()`
- `Design/Spacing.swift`: 4-pt tokens (`xxs 4 … xxl 48`) plus `Radius`.
- `Design/Motion.swift`: durations and curves in one place, each with a Reduce Motion counterpart (cross-fade duration).
- Surface helper: a translucent panel becomes opaque `deepSea` when `accessibilityReduceTransparency` is on.

## Step 6 — static accessible Harbour
- `Components/LighthouseSceneState.swift`: an enum per spec, with progress clamped `0...1` and `isBeamVisible`.
- `Components/LighthouseScene.swift`: a static `Canvas` drawing sky, stars (seeded and deterministic), sea wave lines, rock, tower, lantern and beam cone, plus a ship in the dawn state. `.accessibilityHidden(true)`. Inputs: `state`, `reduceMotion`, `highContrast`, `date` for later ambience.
- Components:
  - `PrimaryActionButton` / `SecondaryActionButton`: 44 pt minimum, focus ring, wrapping labels
  - `WatchStatusLabel`: the single combined VoiceOver label, e.g. "Lighthouse lit. Watch ends at 7:42 am."
  - `DurationPicker`: duration/end-time segmented control, hour steps or a time picker, accessible adjustable action
- `Features/Harbour/HarbourView` + `HarbourModel` (`@Observable`). It shows the current time, the end time the watch would have, and **Begin watch**. It answers the three questions in CLAUDE.md.
  - There is no logbook link yet. The logbook comes in a later session, and a link to nothing would be a dead control.

## Step 7 — watch flow (no animation yet)
- Services, each a protocol plus a real implementation plus a fake/no-op:
  - `NotificationService`: `UNUserNotificationCenter`, id `watch.complete`, body "Morning. Your watch is complete." Requests permission only when the user turns on a "Morning notification" toggle in setup. On denial it shows the CLAUDE.md copy and continues.
  - `OrientationService`: `CMMotionManager` device motion, `gravity.z > 0.85` held for 1.0 s, delivered as an `AsyncStream<OrientationEvent>` (`faceDown`, `unavailable`). Started in `.task` on the prompt and stopped on disappear or cancel. Never logged or persisted.
  - `HapticsService`: a CoreHaptics single transient for ignition and completion. Respects the preference and `supportsHaptics`.
- `App/AppEnvironment.swift`: builds real or fake services. Launch arguments for UI tests:
  - `-uitest`: fakes, plus an on-disk temp store so relaunch tests work
  - `-uitest-reset`
  - `-uitest-now <ISO8601>`
  - `-uitest-notifications-denied`
  - `-uitest-facedown-after <s>`
- Flow, with explicit navigation state (an enum) in `AppRootView`:
  - **Harbour**
  - **Setup sheet**: DurationPicker plus the notification toggle. Remembers the last valid plan.
  - **Face-down prompt**: "Turn your phone face down." The always-visible **Start without turning over** button and the motion event both call one `WatchFlowModel.begin()`.
  - **Active watch**: end time, remaining time (via `TimelineView(.periodic(by: 60))`, display only), and lighthouse lit. **End watch** is secondary and confirmed by a `confirmationDialog`. Interrupting cancels the notification.
  - **Completed**: dawn scene, "Watch kept for 8 hr 0 min", start/finish times, and **Done**. This is a minimal version; the morning log with reflection comes in a later session.
- `reconcile()` runs on launch and on `scenePhase == .active`. VoiceOver announcements (`AccessibilityNotification.Announcement`) on start, interrupt and complete.
- Persistence failure shows "The watch could not be saved. Try again before putting your phone down." and stays on the prompt.

## Step 8 — motion
- Ignition: `KeyframeAnimator` drives night settling → lantern warming to gold → one beam sweep → one haptic → controls simplifying.
- Ambience: a `TimelineView(.animation(paused: !visible))` with a slow beam sweep, minimal sea displacement and rare fog drift. It pauses when the scene leaves the screen or the app goes to the background. No per-frame allocations: wave paths are precomputed per size.
- Reduce Motion is a designed still state: an idle → lit cross-fade, a static composed beam cone, static sea and fog, and no sweep or parallax. Text, timing and controls are identical.

## Snapshot helper (`LanternKeeperTests/Support/SnapshotAssert.swift`)
- `ImageRenderer` at a fixed size of 390×844 and scale 2. The reference PNG is stored in `LanternKeeperTests/__Snapshots__/`.
- Record when it's missing or when `SNAPSHOT_RECORD=1`. Comparison allows ≤0.5% differing pixels with a per-channel tolerance.
- Coverage: every `LighthouseSceneState` × {standard, reduceMotion, highContrast} with a fixed `date`, plus Harbour/Active screens at `.large` and `.accessibility3`.

## UI tests this session
First run to first watch (≤3 taps from Harbour), start fallback button visible, relaunch during active watch, end early confirmation, morning completion (via `-uitest-now`), notification-denied flow. Deferred because their screens come later: onboarding and delete-all-history.

## Verification (each step and at the end)
1. `xcodegen generate`
2. `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`: grep the log for `warning:` and fix any new ones.
3. `xcodebuild … test`: unit, snapshot and UI tests.
4. Manual simulator checks with screenshots via `xcrun simctl io booted screenshot`:
   - Reduce Motion: `simctl spawn booted defaults write com.apple.Accessibility ReduceMotionEnabled -bool true`
   - accessibility text size: `xcrun simctl ui booted content_size accessibility-extra-extra-large`
   - increased contrast: `xcrun simctl ui booted increase_contrast enabled`
5. Commit after each step passes.

The final report will list what was not verified on physical hardware: CoreMotion face-down detection, CoreHaptics feel, notification delivery while locked, performance on the oldest supported iPhone, and the real device-restart path.
