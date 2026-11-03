# Habitat

A habit tracker for iPhone. Month calendar with a donut per day, habit list, week view,
reminders, streaks and JSON export/import. Everything stays on the device: no account, no
backend.

SwiftUI, Swift 6, SwiftData, iOS 17 or later.

## Build

Requirements: Xcode (with an iOS simulator runtime), [XcodeGen](https://github.com/yonaskolb/XcodeGen)
and [SwiftLint](https://github.com/realm/SwiftLint).

```sh
xcodegen generate          # creates Habitat.xcodeproj from project.yml (not committed)
open Habitat.xcodeproj
```

To run on your own iPhone, select your personal team under Signing & Capabilities of the
`Habitat` target.

## Checks

```sh
scripts/gate.sh fast   # swiftlint --strict, swift test, simulator build (warnings are errors)
scripts/gate.sh full   # fast + UI tests on the simulator in .run/sim-udid (or HABITAT_SIM_UDID)
```

Build output goes to `build.noindex/`.

## Layout

```
project.yml          XcodeGen spec: app target (App/Habitat) and UI tests (App/HabitatUITests)
HabitatKit/          Swift package
  HabitatCore        pure logic, no SwiftData, no UI
  HabitatData        SwiftData models, repositories, import/export
App/Habitat/         SwiftUI app: Shell/ (tab bar) and Features/<Screen>/
App/HabitatUITests/  UI tests
docs/                plan, decisions, status, conventions
```

Accessibility identifiers and test launch arguments: [docs/accessibility-ids.md](docs/accessibility-ids.md).
