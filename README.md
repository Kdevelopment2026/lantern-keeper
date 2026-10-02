# Lantern Keeper

**Put your phone down. Keep the light on.**

Lantern Keeper is a calm iPhone ritual for ending late-night scrolling. The user starts a watch, places the phone face down, and leaves a lighthouse keeping watch through the night. In the morning, the app records the time they protected and adds a ship to the log.

This is not a sleep tracker, medical product, blocker disguised as a game, or another attention dashboard. It is one clear moment of intention made memorable enough to repeat.

## Status

Product definition and build foundation. The original 16-second concept animation exists, but the application itself has not yet been implemented.

Existing concept assets:

- `../Mobile_apps_promo_animations/projects/lantern-keeper-teaser/scene.html`
- `../Mobile_apps_promo_animations/projects/lantern-keeper-teaser/videos/LanternKeeper_Teaser_9x16.mp4`
- `../Mobile_apps_promo_animations/projects/lantern-keeper-teaser/facts.md`

The animation is a creative reference, not production application code.

## Product promise

At the moment when “one more video” becomes another lost hour, Lantern Keeper gives the user a gentler ending:

1. Choose how long to keep watch.
2. Turn the phone face down.
3. Let the lighthouse remain on duty.
4. Return to a quiet morning log.

The app measures **watch time**, not sleep. It must never claim to know whether the user slept, rested well, or improved their health.

## Who it is for

Lantern Keeper is for adults who:

- lose time to late-night scrolling;
- dislike punitive app blockers;
- want a small, repeatable wind-down ritual;
- respond better to atmosphere than streak pressure;
- value privacy and do not want an account.

## Product principles

### One ritual, not a platform

The primary action is always **Begin watch**. Features must support that action instead of turning the product into a general productivity suite.

### Quiet accountability

The morning log acknowledges what happened without scores, shame, confetti, leaderboards, or manipulative streak-loss warnings.

### The metaphor must explain the state

- The **lantern** is an active watch.
- The **beam** shows that the watch is still running.
- A **ship** is one completed watch.
- **Dawn** means the planned end time has passed.
- A dark lantern means no watch is active.

The interface must remain understandable without knowing the metaphor.

### Honest measurement

Lantern Keeper can reliably store a start time, planned end time, completion state, and user-entered reflection. It cannot prove sleep or prevent every form of phone use. Copy must stay inside those facts.

### Private by default

The MVP has no account, analytics, advertising SDK, or cloud sync. Session history stays on the device.

## Core experience

### First run

Three short screens:

1. **The scroll can end here.** Introduces the late-night moment without judgement.
2. **Set the watch.** Explains that the timer continues even when the screen is locked.
3. **Morning, not metrics.** Shows the simple log and clearly states that the app measures time away, not sleep.

Notification permission is requested only after the user chooses to receive a morning signal. Do not request it on launch.

### Home — the harbour

The home screen is a dark, spacious seascape with one lighthouse and one dominant action.

- Current time and tonight’s suggested end time
- Duration control, defaulting to the last choice
- **Begin watch** button
- A restrained link to the log
- Optional reminder status

No card grid, productivity dashboard, or percentage score.

### Beginning a watch

The user chooses a duration or wake time, then sees:

> Turn your phone face down.

The app may use Core Motion while it is in the foreground to recognise the face-down gesture. A visible **Start without turning over** control must always remain available for accessibility and device compatibility.

When the gesture is recognised:

1. the interface dims;
2. the lantern ignites;
3. the beam sweeps once;
4. a subtle haptic confirms the watch;
5. the app stores the start and target times.

The watch is based on timestamps, not a fragile continuously running timer.

### Active watch

When reopened during a watch, the screen shows the lighthouse at night, the remaining watch time, and two deliberate actions:

- **Return to watch** locks the experience back into its quiet state.
- **End watch** requires a short confirmation and records an interrupted session.

The product does not scold the user for reopening it.

### Morning log

At or after the planned end time, the palette shifts to dawn. The log shows:

- watch time kept;
- start and finish times;
- one new ship for a completed watch;
- an optional reflection: **How do you feel this morning?**

The reflection choices are plain language, optional, and stored locally. They are not converted into a wellness score.

### Logbook

A calm chronological view of completed and interrupted watches:

- weekly shoreline showing nights, not a performance chart;
- total watch time;
- completed watches represented as ships;
- optional notes and morning reflections;
- delete one entry or all history.

No social comparison or public sharing in the MVP.

## MVP screens

1. Launch scene
2. Onboarding
3. Harbour home
4. Watch setup
5. Face-down prompt
6. Active watch
7. Morning log
8. Logbook
9. Settings and privacy

## Visual direction

The visual language comes from maritime night watchkeeping: painted Fresnel light, wet ink skies, chart-line contours, fog, and distant navigation lights. It should feel adult, cinematic, and quiet—never nautical-themed novelty.

### Colour tokens

| Token | Hex | Purpose |
|---|---:|---|
| `night` | `#06141D` | Primary night background |
| `deepSea` | `#0A2630` | Sea, raised surfaces |
| `horizon` | `#244651` | Secondary structure |
| `moon` | `#DCE7E9` | Primary text on night |
| `mist` | `#91A8AD` | Secondary text |
| `lantern` | `#F3C969` | The single active-light accent |
| `dawn` | `#E79A72` | Completed-watch morning state |
| `ink` | `#10232A` | Text on dawn/light surfaces |

The lantern colour is reserved for an active or actionable state. Colour is never the only state indicator.

### Typography

- **New York** for the product name, reflective moments, and morning log headings.
- **SF Pro** for controls, navigation, settings, and explanatory text.
- **SF Mono** with tabular figures for times and durations.

Use system fonts only. Avoid all-caps labels except short clock or compass markings where the visual language genuinely calls for them.

### Layout

The lighthouse is the persistent spatial anchor. Controls occupy the lower safe area as a short vertical sequence; text aligns to a quiet left edge rather than floating in a collection of cards.

```text
┌────────────────────────────┐
│  11:42 pm                  │
│                            │
│                \  beam     │
│             lighthouse     │
│  sea                       │
│                            │
│  Keep watch until          │
│  7:00 am                   │
│                            │
│  [      Begin watch      ] │
│       Open logbook         │
└────────────────────────────┘
```

### Motion

One orchestrated moment carries the identity: the lantern ignition and first beam sweep when a watch begins.

Native SwiftUI only:

- `Canvas` for sea, fog, lighthouse, beam, and ships;
- `TimelineView` for controlled ambient motion while foregrounded;
- `KeyframeAnimator` or `PhaseAnimator` for ignition and state transitions;
- Core Haptics for restrained confirmation;
- timestamp-derived state so reopening never resets the scene.

Ambient motion must be slow and low contrast. Do not scatter looping movement across every control.

### Reduce Motion

With Reduce Motion enabled:

- the lighthouse changes directly from unlit to lit;
- the beam appears as a composed static cone;
- the sea and fog do not drift;
- transitions use a short cross-fade;
- all status information remains present in text.

## Accessibility

- Support Dynamic Type through accessibility sizes.
- Maintain WCAG AA contrast for text and controls.
- Minimum 44×44 pt interactive targets.
- Provide VoiceOver descriptions for the lighthouse state and each meaningful control.
- Announce watch start, interruption, and completion without relying on animation.
- Do not require a face-down gesture; every gesture has a visible control equivalent.
- Support Reduce Motion, Reduce Transparency, Increased Contrast, and Differentiate Without Colour.
- Never place essential text inside the animated canvas.

## Technology

- iOS 17+
- Swift 5.10+
- SwiftUI
- SwiftData for local history and preferences
- UserNotifications for optional end-of-watch and morning reminders
- Core Motion for foreground-only face-down detection
- Core Haptics for ignition feedback
- XCTest and XCUITest
- XcodeGen, with `project.yml` as project source of truth

No third-party packages are required for the MVP.

### Optional future capability

Apple’s FamilyControls, ManagedSettings, and DeviceActivity frameworks may support a stronger distraction-shield mode, but they require user authorisation and Apple-granted entitlements. They are not part of the first build and must never be simulated or promised before approval.

## Architecture

The app uses a small feature-first structure with observable stores and protocol-backed services.

```text
LanternKeeper/
├── App/
├── Design/
├── Models/
├── Services/
├── Features/
│   ├── Onboarding/
│   ├── Harbour/
│   ├── Watch/
│   ├── MorningLog/
│   ├── Logbook/
│   └── Settings/
├── Components/
├── Resources/
└── SupportingFiles/
LanternKeeperTests/
LanternKeeperUITests/
project.yml
```

Key service boundaries:

- `Clock`: makes time-dependent behaviour testable.
- `WatchStore`: starts, restores, completes, and interrupts watches.
- `NotificationService`: requests permission and schedules local notifications.
- `OrientationService`: exposes optional foreground face-down events.
- `HapticsService`: centralises accessible haptic behaviour.

## Data model

### WatchSession

- `id: UUID`
- `startedAt: Date`
- `targetEndAt: Date`
- `endedAt: Date?`
- `status: active | completed | interrupted`
- `reflection: morning | steady | tired | skipped`
- `note: String?`

### Preferences

- default duration
- morning notification choice
- haptics choice
- onboarding completion
- last selected end time

Only one watch may be active at a time.

## Privacy and safety

- All MVP data remains on device.
- No account or sign-in.
- No analytics, ad SDK, crash-reporting SDK, or remote configuration.
- No health diagnosis or sleep-quality claim.
- No background microphone, camera, or continuous sensor collection.
- Orientation data is used transiently and is never persisted.
- Users can delete all history from Settings.

## Monetisation

The MVP has no paywall. The complete nightly ritual, active watch, morning log, and local history are free.

An optional paid tier may be explored after product validation for aesthetic themes, richer long-term reflections, and device sync. It must never interrupt an active watch or place the user’s own recent history behind a sudden paywall.

## Build phases

### Phase 1 — foundation

- Generate the Xcode project.
- Add design tokens and system typography.
- Implement data models, clock abstraction, and watch state restoration.
- Build the static lighthouse scene with accessible text equivalents.

### Phase 2 — ritual

- Build onboarding, harbour, watch setup, and active-watch flow.
- Add optional face-down recognition and visible fallback control.
- Add local notifications and timestamp-based restoration.

### Phase 3 — identity

- Add native lighthouse ignition, beam, sea, fog, dawn, and ship animations.
- Implement complete Reduce Motion equivalents.
- Tune haptics, transitions, and sound policy. Audio remains off by default.

### Phase 4 — morning and history

- Build morning log, optional reflection, and logbook.
- Add deletion and privacy controls.
- Test date changes, daylight-saving transitions, interruptions, and device restarts.

### Phase 5 — release quality

- VoiceOver and Dynamic Type pass.
- Unit, snapshot, and UI tests.
- App icon, launch screen, privacy manifest, and App Store copy.
- TestFlight build on physical devices.

## MVP acceptance criteria

- A watch can be started in three taps or fewer from the home screen.
- A watch survives app termination and device restart because state derives from stored dates.
- Reopening during a watch never loses or duplicates the active session.
- Completion and interruption are accurately distinguished.
- Notification denial does not block any core feature.
- The face-down gesture is optional.
- Every animated scene has a composed Reduce Motion state.
- Dynamic Type remains usable at accessibility sizes.
- All meaningful canvas states have VoiceOver equivalents.
- The app makes no unsupported claim about sleep or device blocking.
- Tests cover midnight, daylight-saving changes, and clock manipulation.

## Non-goals for the first release

- Social feeds or sharing
- Competitive streaks
- Medical or sleep analysis
- Apple Watch app
- Android version
- Cloud accounts or cross-device sync
- Screen Time blocking entitlements
- AI coaching
- Subscriptions or paywalls

## Product voice

Short, calm, adult, and literal beneath the metaphor.

Use:

- **Begin watch**
- **The light is on**
- **Watch kept for 7 hr 42 min**
- **End watch**
- **No judgement. Begin again tonight.**

Avoid:

- “Crush your goals”
- “You failed your streak”
- “Sleep score”
- “Digital detox”
- “Addiction”
- childish reward language
- exclamation marks in routine interface copy

## Name and positioning

**Lantern Keeper**  
*Put your phone down. Keep the light on.*

The name describes a role, not a score. The user is not being controlled by the app; they are choosing to keep watch over the time they want back.
