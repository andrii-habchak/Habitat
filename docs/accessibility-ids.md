# Accessibility identifiers

Every interactive element (and every element a UI test needs to find) gets an
accessibility identifier of the form:

```
<screen>.<element>[.<id>]
```

- `screen`: the screen or area, lower camel case: `tabs`, `habits`, `habitEditor`, `week`,
  `month`, `daySheet`, `reminders`, `reminderEditor`, `settings`.
- `element`: what it is on that screen, lower camel case: `addButton`, `row`, `toggle`,
  `nameField`, `placeholder`, `errorMessage`.
- `id` (optional): which instance, when there are many: a habit's UUID, a day as
  `yyyy-MM-dd`, a reminder's UUID. Combine with `.` if two keys are needed, e.g.
  `week.cell.<habitId>.2026-11-03`.

Examples:

| Identifier | Element |
|------------|---------|
| `tabs.habits` | Habits tab bar item |
| `habits.placeholder` | placeholder content of a screen not built yet |
| `habits.addButton` | add-habit button |
| `habits.row.<habitId>` | a habit's row in the list |
| `week.cell.<habitId>.<yyyy-MM-dd>` | a habit/day toggle in the week grid |
| `month.day.<yyyy-MM-dd>` | a day's donut in the month grid |

Rules:

- Identifiers are stable, never localised and never shown to the user. Labels (what VoiceOver
  reads) are separate and must be set too (R-A11Y).
- State that tests check (done / not done, weekly status, donut segments) goes in the
  accessibility **value**, not in the identifier.
- In the app, build identifiers with `AccessibilityID.make(screen, element, id)`
  (`App/Habitat/Shell/AccessibilityID.swift`); UI tests use the literal strings.
- Tab bar buttons: SwiftUI does not reliably pass an identifier set inside `.tabItem` to the
  tab bar button, so UI tests find tab buttons by their label (`app.tabBars.buttons["Habits"]`).
  The `tabs.<tab>` identifier is still set for when it does.

## Launch arguments for tests

Parsed by `LaunchOptions` (`HabitatKit/Sources/HabitatCore/LaunchOptions.swift`):

| Argument | Effect |
|----------|--------|
| `-uiTesting` | in-memory store, nothing written to disk |
| `-seed <fixture>` | load the named seed fixture (fixtures arrive in P2) |
| `-today yyyy-MM-dd` | pin "today" to that day; an invalid day is ignored |
| `-fakeNotifications` | use the fake notification scheduler (P2/P6) |
