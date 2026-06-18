# Calender_Aralrm — Shift Alarm

A calendar-driven alarm app for shift workers (day/night shifts, 3-shift / 4-on-2-off rotations).
The app uses **AlarmKit** (iOS 26+) so alarms fire with the same reliability as the system Clock —
piercing silent and focus modes, presenting on the lock screen, and showing a Live Activity.

The repository targets iOS 26.0+, Swift 6, SwiftUI / SwiftData, with a Widget Extension for
home-screen and Dynamic Island.

See `README.ja.md` for a Japanese version.

## Features

- Month calendar — assign a preset per date with optional time overrides and skip flag.
- Shift presets — name, color, default alarm time, sound.
- Rotation patterns — define cyclic sequences (e.g. 4-on/2-off, 3-shift) with anchor date,
  applied range, and priority.
- Holiday / PTO overrides — skip alarms or substitute a preset on public holidays or vacation days.
  Includes a bundled Japanese public-holiday table.
- Share / import — export presets, patterns, assignments, and overrides as a `.shiftalarm` JSON file,
  or import via `fileImporter`. URL scheme `shiftalarm://import?payload=<base64-json>` is also supported.
- Widget — home screen and Lock Screen widget showing the next alarm, with a
  multi-entry timeline that transitions naturally as upcoming alarms approach.
- Live Activity — Dynamic Island countdown that appears within configurable hours before the alarm.
- Sleep schedule & Bedtime reminder — derive bedtime from the wake time
  (`targetSleepDuration`) and schedule a T-N minute reminder
  (`bedtimeLeadMinutes`) alongside the main alarm.
- HealthKit & Shortcuts — write sleep samples to HealthKit and expose the next
  sleep window via App Intents (`GetSleepWindowIntent`) for Siri / Shortcuts.
- Onboarding — first-launch flow that requests AlarmKit authorization and
  seeds sample presets so a user can fire the first alarm within a few taps.

## Project layout

```
Calender_Aralrm/
├── project.yml                 # XcodeGen source of truth
├── scripts/                    # bootstrap.sh, regen.sh, verify.sh
├── App/                        # Main app target (@main, Info.plist, entitlements)
├── Sources/
│   ├── Domain/                 # SwiftData @Model + pure logic (Resolver, Expander)
│   ├── Services/               # AlarmKit, Background, LiveActivity, Sharing, Holidays
│   ├── Features/               # SwiftUI screens (Calendar, Presets, Rotation, etc.)
│   └── Shared/                 # Extensions, URL scheme router
├── Resources/                  # Localizable.xcstrings, InfoPlist.xcstrings, HolidaysJP.json
├── Widget/                     # Widget Extension + Live Activity
└── Tests/                      # Swift Testing unit tests
```

## Build

You need macOS with Xcode 26.0+ and Homebrew installed.

```sh
# 1. Install XcodeGen (only once per machine)
bash scripts/bootstrap.sh

# 2. Generate ShiftAlarm.xcodeproj from project.yml
bash scripts/regen.sh

# 3. Verify build and tests on an available iOS 26 simulator
bash scripts/verify.sh

# 4. Open and run
open ShiftAlarm.xcodeproj
```

In Xcode, select the **ShiftAlarm** scheme and an iOS 26 simulator (or device with an Apple
Developer account that has the AlarmKit entitlement). Press `⌘R` to build and run.

`scripts/verify.sh` regenerates the Xcode project, picks an available iOS 26 iPhone simulator, and
runs both build and tests. To use a specific destination:

```sh
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' bash scripts/verify.sh
```

## Testing manually (golden path)

1. Settings → "Request permission" to grant AlarmKit access.
2. Presets → create "Night shift 20:00" and "Day shift 06:30".
3. Calendar → tap tomorrow → assign "Night shift".
4. Advance the simulator clock and verify the AlarmKit alert appears.
5. Rotation → create "4-on/2-off" with anchor = today; verify the calendar reflects the pattern.
6. Settings → Holidays → "Import Japanese public holidays"; verify a holiday cell loses its alarm.
7. Settings → Export → save the `.shiftalarm` file. On another simulator: Settings → Import → pick
   the file → verify the diff preview, then apply.
8. Long-press the home screen and add the **Next alarm** widget.

## Unit tests

```sh
bash scripts/verify.sh test
```

The Tests target is written with Apple's [Swift Testing](https://developer.apple.com/documentation/testing)
(`@Test` / `#expect`) and currently runs 131 tests across 19 test suites (22 files) covering domain,
services, App Intents, HealthKit helpers, background refresh, deep links, sharing, and snapshot
coverage. Six snapshot tests are skipped by default unless `SNAPSHOT_TESTING_ENABLED=1` is
set.

## Code style

Swift sources are formatted with [`swift-format`](https://github.com/swiftlang/swift-format),
bundled with the Xcode 26 toolchain and configured by `.swift-format` at the repository root.
CI fails the `lint` job on any violation.

```sh
bash scripts/lint.sh check   # lint, non-zero exit on violations
bash scripts/lint.sh fix     # reformat in place
```

## Architecture notes

- `AlarmScheduler` (`Sources/Services/AlarmKit/AlarmScheduler.swift`) is the heart of the app. It
  diff-syncs the expected set of alarms (from `DayResolver`) against AlarmKit's registered alarms,
  scheduling/cancelling only the differences.
- `DayResolver` resolves per-date precedence as **manual > holiday > rotation > none**. Note one
  intentional exception: a holiday override with `skipAlarm == false` and no replacement preset
  falls through to rotation resolution, so the normal scheduled alarm still fires
  (`Sources/Domain/Logic/DayResolver.swift`).
- `BGAppRefreshTask` keeps the lookahead window (default 30 days) populated when the app is
  backgrounded.
- The Widget shares state through the configured App Group (default:
  `group.com.example.shiftalarm`) SwiftData store.
- AlarmKit SDK is referenced via `#if canImport(AlarmKit)` so the codebase still parses on
  toolchains without the SDK. The AlarmKit / ActivityKit API surface was checked against Xcode 26.5;
  `AlarmConfigurationBuilder` uses the current `AlarmManager.AlarmConfiguration.alarm(...)` factory
  and avoids the iOS 26.1 `AlarmPresentation.Alert.stopButton` deprecation when possible.

## Customizing the bundle id / app group

For simulator builds, the defaults in `Config/SigningDefaults.xcconfig` are enough. For real-device
AlarmKit validation, copy `Config/LocalSigning.xcconfig.example` to
`Config/LocalSigning.xcconfig`, fill the Apple Developer Team ID plus registered bundle IDs and App
Group, then run:

```sh
bash scripts/regen.sh
bash scripts/p0-readiness.sh
bash scripts/p0-device-build.sh
```

`Config/LocalSigning.xcconfig` is ignored by git so local signing values do not leak into commits.
The readiness script intentionally fails while the default `com.example.*` placeholders are still in
use. The device build script runs the same readiness check before building for
`generic/platform=iOS`.

## Roadmap

Recently shipped:

- **Shift-pattern auto-detection** — analyzes existing assignments and suggests a ready-to-use
  rotation when a periodic schedule (e.g. weekly day/night alternation, or a multi-week cycle)
  is detected.
- **Family calendar export (`.ics`)** — export assignments as a standard `.ics` file so family
  members can subscribe from their own calendar app.
- **`.shiftalarm` input validation** — semantic checks beyond Codable (hour / minute /
  cycle length / duplicate IDs / size limits / missing preset references) prevent malformed
  share files or URL imports from corrupting the local store.

Designed, not yet implemented:

- **Alarm reliability diagnostics** — a settings screen that shows at a glance whether the
  next alarm will actually fire (permissions, scheduler sync, App Group, BG refresh,
  Live Activity, HealthKit), with one-tap recovery actions when something is off.
- **Unified diff preview** — a shared change-preview abstraction reused by `.shiftalarm`
  import, image import, pattern-drift suggestions, and day-of-week rule expansion, so
  every destructive change is reviewed before it lands.
- **Vacation-aware shift flip** — let users mark long holidays (お盆 / GW etc.) as a single
  vacation block, and apply a configurable policy (invert / continue / reset-to-day) to
  the shift that resumes after the break.
- **Shift-roster image import** — Phase 1 ships a manual grid + symbol-mapping flow that
  works even when OCR fails; Phase 2 layers on `Vision` OCR for automatic extraction;
  Phase 3 adds iOS 26 `FoundationModels` for label interpretation. On-device only —
  no cloud round-trip.

iCloud sync and an Apple Watch companion were considered earlier and are now **out of
scope**. See `ROADMAP.md` for the full phased plan.

## License

MIT. See `LICENSE`.
