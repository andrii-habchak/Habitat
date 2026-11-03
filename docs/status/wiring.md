# Shared wiring: status

Branch `ph/shared-wiring`. Shared app code the feature lanes build on. Lanes add views only
under `App/Habitat/Features/<Name>/`.

## API for lanes

```swift
@Environment(\.services) private var services      // AppServices
@Environment(\.appContext) private var appContext  // launch options, store configuration
```

`AppServices` (`Shared/AppServices.swift`):

- `services.today: DayKey` is the injected clock's day (`-today` honoured).
- `services.clock: any Clock`, `services.container: ModelContainer`.
- Main-actor factories over the container's `mainContext`: `habitRepository()`,
  `completionRepository()`, `reminderRepository()`, `dataTransfer()`. Build where used.
- `services.context` is the `mainContext`. `.modelContainer(...)` is attached in `HabitatApp`.
- Without injection (previews) the default is an empty in-memory store with the system clock.

`HabitatApp`: `HabitatStore.prepare(storeConfiguration, clock:)` (seeds from `-seed`); a failure
ends in `fatalError("Habitat could not open its data store: ...")`.

`Theme` (`Shared/Theme.swift`):

- `Color(hex: "#RRGGBB")` (invalid gives grey).
- `Theme.habitPalette: [String]` (8 hex colours), `Theme.defaultHabitColorHex`.
- `Theme.Status.met / .failed / .inProgress`: adaptive text/icon colours for weekly status
  (green / red / amber, 4.5:1 or better on the system background in light and dark). Pair with a
  symbol or label.
- `Theme.Spacing.extraSmall/small/medium/large/extraLarge` (4/8/16/24/32), `Theme.Radius.card`, `Theme.minTapTarget` (44).

Tab shell unchanged: each `Features/<Tab>View` still shows `FeaturePlaceholder` with
`<tab>.placeholder` until its lane replaces it.
