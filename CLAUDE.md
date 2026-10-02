# CLAUDE.md — Lantern Keeper

Instructions for AI coding agents working in this repository. Read `README.md` first for the product definition, then this file before changing code.

## Mission

Build a production-quality native iPhone app that helps an adult end late-night scrolling through one calm ritual: begin a watch, put the phone down, and return to a morning log.

The app’s signature is a lighthouse whose light remains on while the watch is active. The visual metaphor is important, but honest behaviour, accessibility, and reliability come first.

## Non-negotiable product rules

1. **Measure watch time, never sleep.** The app does not know whether someone slept. Do not use “sleep tracked”, “sleep quality”, “deep sleep”, “recovery”, or a sleep score.
2. **Do not claim to block other apps.** The MVP has no Screen Time entitlement. A timer and ritual are not an app blocker.
3. **No shame mechanics.** No streak loss, red failure state, countdown anxiety, leaderboards, points, or scolding notifications.
4. **The core ritual stays free.** Do not add StoreKit, subscriptions, trial gates, or paywalls during the MVP build.
5. **Local and private.** No account, analytics, advertising, remote config, telemetry SDK, or network service.
6. **No third-party dependencies.** Use Apple frameworks and SwiftUI. If a feature appears to require a package, redesign it first.
7. **Accessibility is part of the component contract.** VoiceOver, Dynamic Type, contrast, 44×44 pt targets, and system accessibility settings must work before a feature is complete.
8. **Reduce Motion gets a designed still state.** Do not merely set animation duration to zero.
9. **The face-down gesture is optional.** Always provide a visible button alternative.
10. **One active watch only.** Enforce this in the model and store, not just in the interface.
11. **Time derives from dates.** Never depend on an in-memory timer count for correctness.
12. **Keep essential content outside Canvas.** Canvas is decorative and atmospheric; status, time, and controls remain accessible SwiftUI views.

## Platform and toolchain

- iOS 17+
- Swift 5.10+
- SwiftUI
- SwiftData
- XCTest and XCUITest
- XcodeGen
- No Swift Package Manager dependencies

Use `project.yml` as the source of truth. Do not hand-edit generated `.xcodeproj` settings.

Apple frameworks allowed for the MVP:

- SwiftUI
- SwiftData
- UserNotifications
- CoreMotion
- CoreHaptics
- OSLog

Do not add HealthKit. Do not add FamilyControls, ManagedSettings, or DeviceActivity until the repository has a separate entitlement-approved build plan.

## First-session build order

1. Create the XcodeGen structure and generate the project.
2. Build the empty app for an iPhone simulator.
3. Add the domain models and a deterministic `Clock`.
4. Add unit tests for watch lifecycle and restoration.
5. Add the design system.
6. Build one static, accessible Harbour screen.
7. Add the watch flow without motion.
8. Add motion only after the state machine is tested.

At every numbered step:

- generate the project if structure changed;
- build with warnings treated seriously;
- run the relevant tests;
- do not continue from a broken build.

## Architecture

Use feature-first folders with a small domain layer and protocol-backed system services.

```text
LanternKeeper/
├── App/
│   ├── LanternKeeperApp.swift
│   ├── AppRootView.swift
│   └── AppEnvironment.swift
├── Design/
│   ├── Palette.swift
│   ├── TypeScale.swift
│   ├── Spacing.swift
│   └── Motion.swift
├── Models/
│   ├── WatchSession.swift
│   ├── WatchStatus.swift
│   ├── MorningReflection.swift
│   └── UserPreferences.swift
├── Services/
│   ├── Clock.swift
│   ├── WatchStore.swift
│   ├── NotificationService.swift
│   ├── OrientationService.swift
│   └── HapticsService.swift
├── Features/
│   ├── Onboarding/
│   ├── Harbour/
│   ├── Watch/
│   ├── MorningLog/
│   ├── Logbook/
│   └── Settings/
├── Components/
│   ├── LighthouseScene.swift
│   ├── PrimaryActionButton.swift
│   ├── DurationPicker.swift
│   └── WatchStatusLabel.swift
├── Resources/
└── SupportingFiles/
LanternKeeperTests/
LanternKeeperUITests/
project.yml
```

### Dependency direction

- Features may depend on Models, Services protocols, Design, and Components.
- Services may depend on Models and Apple frameworks.
- Models do not depend on views or system services.
- Components do not start or mutate watches directly.
- No global singleton except Apple-owned framework entry points hidden behind services.

Use constructor or environment injection for services. Tests must be able to supply a fixed clock, in-memory store, no-op notifications, and no-op haptics.

## Domain model

### WatchSession

SwiftData model fields:

```swift
id: UUID
startedAt: Date
targetEndAt: Date
endedAt: Date?
statusRawValue: String
reflectionRawValue: String?
note: String?
```

Expose typed computed properties for status and reflection. Keep persistence migration-friendly; do not store derived durations.

### WatchStatus

```swift
enum WatchStatus: String, Codable, CaseIterable {
    case active
    case completed
    case interrupted
}
```

### MorningReflection

Use optional, non-clinical language:

```swift
enum MorningReflection: String, Codable, CaseIterable {
    case clear
    case steady
    case tired
}
```

“Skip” means no value and is not a stored reflection case.

### Watch lifecycle

Allowed transitions:

```text
none ──begin──> active
active ──target reached──> completed
active ──user ends──> interrupted
```

Completed and interrupted records are immutable except for optional reflection and note. Starting a new watch must first reconcile any persisted active session against the current clock.

## Time correctness

All time-sensitive code uses a `Clock` protocol:

```swift
protocol Clock: Sendable {
    var now: Date { get }
}
```

Rules:

- Calculate remaining time as `targetEndAt.timeIntervalSince(clock.now)`.
- Persist absolute dates.
- Format dates in the user’s current locale and time zone.
- Reconcile state when the app becomes active.
- If `now >= targetEndAt`, complete the watch once.
- Protect completion with an idempotent store operation.
- Test watches that cross midnight and daylight-saving boundaries.
- Do not run a per-second persistence loop.

The display may refresh through `TimelineView`, but display refresh is not business logic.

## Services

### WatchStore

Responsibilities:

- find the current active watch;
- reject a second active watch;
- begin a watch with validated dates;
- reconcile a watch with the clock;
- complete or interrupt exactly once;
- load logbook entries newest first;
- update reflection and note;
- delete entries and all history.

Business rules belong here or in a dedicated domain type, never only in a view.

### NotificationService

- Ask for permission only after explicit user intent.
- Schedule optional local notifications using stable identifiers.
- Cancel or replace notifications when a watch changes.
- The app remains fully functional when permission is denied.
- Notification text stays neutral: **Morning. Your watch is complete.**
- Do not use guilt, urgency, or marketing copy.

### OrientationService

- Observe device orientation only while the face-down prompt is foregrounded.
- Convert raw motion into a debounced semantic event.
- Never persist motion samples.
- Stop updates immediately when the prompt leaves the screen.
- Expose unavailable and denied states without blocking the flow.
- Simulator and tests use a fake service.

### HapticsService

Use restrained feedback for watch ignition, selection, and completion. Respect the user’s in-app haptics choice and system capabilities.

## State management

Prefer Swift’s Observation framework with `@Observable` feature models owned by the relevant screen flow. Keep navigation state explicit.

Avoid:

- a single app-wide mega-store;
- view models that merely mirror every view property;
- business logic in `onAppear` without an idempotent model method;
- notification callbacks directly mutating views;
- detached tasks without cancellation ownership.

All UI updates occur on the main actor. Persistence and service APIs declare actor isolation deliberately.

## Design system

Never hard-code colours, spacing, radii, or animation timing inside feature views.

### Palette

```text
night      #06141D
deepSea    #0A2630
horizon    #244651
moon       #DCE7E9
mist       #91A8AD
lantern    #F3C969
dawn       #E79A72
ink        #10232A
```

Provide semantic colours for:

- background
- raised background
- primary text
- secondary text
- action
- focus ring
- completed state
- interrupted state

Do not use red for an interrupted watch. Interruption is information, not failure.

### Typography

- New York: wordmark and reflective morning headings
- SF Pro: interface text
- SF Mono: times and durations

All styles use Dynamic Type APIs. Never fix a text container to one line if accessibility sizes could require wrapping.

### Spacing

Use a 4-point base scale with named tokens. Prefer generous negative space and one clear control group over nested cards.

### Components

The primary button, duration control, watch status, reflection selector, and settings rows must have reusable accessible components. Reuse must not flatten meaningful visual hierarchy.

## Lighthouse scene

`LighthouseScene` is a native SwiftUI composition. It may use `Canvas` for atmospheric drawing, but it receives a simple immutable state:

```swift
enum LighthouseSceneState: Equatable {
    case idle
    case igniting
    case watching(progress: Double)
    case dawn
    case interrupted
}
```

Scene rules:

- Clamp progress to `0...1`.
- The beam is visible only for igniting or watching.
- Ships in the logbook are symbolic completed-watch marks, never live maritime data.
- Never render essential text into Canvas.
- Decorative layers use `.accessibilityHidden(true)`.
- The containing view exposes one concise state label, such as “Lighthouse lit. Watch ends at 7:00 am.”
- Keep drawing deterministic for snapshot tests.
- Avoid heavy blur chains and unbounded particle systems.

## Motion direction

Spend motion on the transition into a watch:

1. night settles;
2. the lantern warms from dark to gold;
3. the beam sweeps once across the water;
4. one haptic confirms the state;
5. controls simplify to the active-watch layout.

Ambient foreground motion:

- a slow beam sweep;
- minimal sea displacement;
- rare fog movement;
- no bouncing controls or decorative entrance animation on every element.

### Reduce Motion contract

Read `accessibilityReduceMotion` at the feature boundary and pass it into animated components where necessary.

Reduced state:

- cross-fade from idle to a fully composed lit lighthouse;
- static beam cone;
- static sea and fog;
- no parallax, scaling, or path travel;
- identical text, timing state, and controls.

### Reduce Transparency and contrast

Replace translucent fog-backed panels with opaque `deepSea` surfaces when Reduce Transparency is enabled. Increased Contrast strengthens text and focus outlines without introducing a different information hierarchy.

## Screen specifications

### Launch

A static native launch screen uses the exact `night` background. The first SwiftUI frame must match it without a flash. A short lighthouse reveal may run after handoff, but launch must not delay access to the app.

### Onboarding

Three pages maximum. Skip remains visible. No permission request occurs until a feature needs it. The final page leads directly to Harbour.

### Harbour

Must answer three questions immediately:

1. Is a watch active?
2. If not, when would this watch end?
3. What is the next action?

One dominant button only. The logbook is secondary navigation.

### Watch setup

Offer a duration and end-time mode, but keep the default path simple. Validate that the target end time is in the future. Remember the last valid choice locally.

### Face-down prompt

The gesture and **Start without turning over** button lead to the same domain action. Do not create two start implementations.

### Active watch

Show end time, remaining time, and lighthouse state. Hide exploratory navigation that encourages lingering. **End watch** is visible but visually secondary.

### Morning log

Use the exact measured duration. Ask for an optional reflection only after presenting the result. Do not infer mood or sleep.

### Logbook

Use chronological entries and a subdued shoreline summary. Charts must remain legible with VoiceOver and cannot be the only representation of history.

### Settings

Include:

- default watch duration;
- optional notifications;
- haptics;
- appearance if implemented;
- privacy explanation;
- delete all history;
- version information.

Deleting all history requires confirmation and is irreversible. Clearly describe what will be removed.

## Copy rules

Voice: calm, adult, concise, non-clinical.

Approved terms:

- watch
- begin watch
- keep the light on
- watch time
- morning log
- completed
- ended early

Avoid:

- sleep tracked
- sleep score
- failure
- addiction
- detox
- productivity score
- perfect night
- streak lost
- shame-based or childish reward copy

Use sentence case. Exclamation marks should not appear in routine interface copy.

## Privacy requirements

The privacy manifest must accurately declare that the MVP does not track users or collect data. Do not add networking capabilities “for later”. Do not log notes, reflections, exact session times, notification content, or motion values.

OSLog entries may describe lifecycle events using non-sensitive categories, for example “active watch reconciled”, without identifiers or timestamps beyond system log metadata.

## Error handling

Errors explain what happened and what the user can do:

- Notification denied: **Morning notifications are off. Your watch will still continue.**
- Motion unavailable: **Turn detection isn’t available. Start the watch when you’re ready.**
- Persistence failure: **The watch could not be saved. Try again before putting your phone down.**

Never pretend a watch started if persistence failed.

## Testing requirements

### Unit tests

- starts a valid watch;
- rejects an end time in the past;
- prevents two active watches;
- restores an active watch;
- completes exactly once after target time;
- records an early end as interrupted;
- crosses midnight correctly;
- handles daylight-saving transitions using absolute dates;
- notification denial leaves the watch usable;
- deletion removes the correct entries;
- reflection updates do not change measured duration.

### View and snapshot tests

Cover every lighthouse state in:

- standard motion;
- Reduce Motion;
- Increased Contrast;
- light/dawn and night palettes;
- default and accessibility Dynamic Type.

### UI tests

- first run to first watch;
- visible start fallback without motion gesture;
- reopen during active watch;
- end early confirmation;
- morning completion;
- notification-denied flow;
- delete all history.

Use launch arguments and injected clocks to avoid waiting for real time in tests.

## Performance budget

- Maintain smooth animation on the oldest supported iPhone class.
- Pause TimelineView-driven ambience when the scene is not visible.
- Avoid per-frame allocations where practical.
- Do not keep Core Motion active beyond the face-down prompt.
- Profile Canvas work before adding blur, noise, or particles.
- The app must remain useful with all animation disabled.

## Build and verification

After adding or removing source files:

```sh
xcodegen generate
```

Build:

```sh
xcodebuild -project LanternKeeper.xcodeproj \
  -scheme LanternKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Test:

```sh
xcodebuild -project LanternKeeper.xcodeproj \
  -scheme LanternKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

If that simulator is unavailable, list installed simulator devices and select an available iOS 17+ device. Do not change deployment target merely to satisfy the local simulator list.

Before reporting completion:

- build the app;
- run tests;
- inspect warnings;
- test with Reduce Motion;
- test an accessibility Dynamic Type size;
- state clearly what was not tested on physical hardware.

## Out of scope until explicitly requested

- paywall or StoreKit
- cloud sync or accounts
- Android
- Apple Watch
- HealthKit
- Screen Time blocking
- social sharing
- AI-generated coaching
- live maritime or weather data
- third-party analytics

Do not prepare hidden scaffolding for out-of-scope services.

## Definition of done

A feature is complete only when:

- its domain behaviour is tested;
- it builds without new warnings;
- persisted state restores correctly;
- VoiceOver describes its meaning;
- Dynamic Type does not truncate its critical content;
- Reduce Motion has a composed equivalent;
- denied permissions have a usable fallback;
- copy stays inside the product’s factual capabilities;
- no new network or third-party dependency has appeared.

## Product sentence to protect

> Lantern Keeper helps you put the phone down; it does not pretend to know what happens after.

When a proposed feature conflicts with that sentence, leave it out and document the reason.
