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
- Widget — home screen and Lock Screen widget showing the next alarm.
- Live Activity — Dynamic Island countdown that appears within configurable hours before the alarm.

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
└── Tests/                      # XCTest unit tests
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

The Tests target covers rotation expansion, day resolver priority logic, and the share-bundle
codec.

## Architecture notes

- `AlarmScheduler` (`Sources/Services/AlarmKit/AlarmScheduler.swift`) is the heart of the app. It
  diff-syncs the expected set of alarms (from `DayResolver`) against AlarmKit's registered alarms,
  scheduling/cancelling only the differences.
- `DayResolver` resolves per-date precedence as **manual > holiday > rotation > none**.
- `BGAppRefreshTask` keeps the lookahead window (default 30 days) populated when the app is
  backgrounded.
- The Widget shares state through an App Group (`group.com.example.shiftalarm`) SwiftData store.
- AlarmKit SDK is referenced via `#if canImport(AlarmKit)` so the codebase still parses on
  toolchains without the SDK; the unit tests run on any iOS 17+ simulator.

## Customizing the bundle id / app group

Edit `project.yml` (top-level `options.bundleIdPrefix` and the entitlements files) and re-run
`scripts/regen.sh`.

## Roadmap (designed for, not yet implemented)

- iCloud sync via `ModelConfiguration(cloudKitDatabase:)`
- Bedtime reminder T-N hours before each alarm
- Apple Watch companion using the shared `Sources/Domain` target

## License

MIT. See `LICENSE`.
