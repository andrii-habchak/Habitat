# fix-qa57 — status

Branch `ph/fix-qa57` (from integration 72ffd87). Owned: `App/Habitat/**`, `HabitatKit/**`,
`project.yml`, this file, `docs/accessibility-ids.md`. `App/HabitatUITests/**` untouched.

## What was run

- `scripts/gate.sh fast` after each commit (lint, package tests, build-for-testing): PASS.
- No simulator was used or created. The new/changed `HabitatTests` unit tests are only compiled,
  not run. UI audits are not run: QA must re-run them and remove the `XCTExpectFailure`
  wrappers (BUG-QA57-3..8) and the BUG-QA57-1 wrappers.

## Fixes

1. BUG-QA57-1 (month names): `MonthSymbols` built a `Calendar(identifier: .gregorian)` without a
   locale, which returns placeholder symbols ("M11", "M10"). It now sets the locale
   (`.current` by default, injectable for tests). Title is "November 2026", day labels are
   "Monday 26 October, ..." (the full form QA's tests expect). Tests: `MonthSymbolsTests`.
2. Contrast (BUG-QA57-3..8, 11), by change, all unverified:
   - Month grid: no `.light` weight; out-of-month day numbers use `.primary`; the ring is dimmed
     to 0.85 instead of 0.4; not-done segments 0.85 opacity (was 0.5), so an out-of-month
     not-done segment is about 0.72 effective; the empty
     ring is `.secondary` (about 60 % alpha, a non-text shape; was 0.25 of that); weekday header `.primary`; unselected chips use
     `secondarySystemFill`.
   - Day sheet: row state icon `.primary` (symbol shape carries the state).
   - Reminders list and editor, Settings: section headers set to `.primary`; reminder label
     field text `.primary`. The text field placeholder colour is system-controlled and was left.
3. BUG-QA57-2: in `DaySheet` `.disabled(isFuture)` now comes after `accessibilityElement(.ignore)`
   so the disabled state reaches the exposed element.
4. BUG-QA57-9/10: reminder row label is "<kind>: <title>, <spoken time with AM/PM or 24 h>,
   <full weekday names>" (only all seven days read "Every day"; weekdays/weekends are spelled
   out). Habit reminder rows no longer repeat the habit name under the section header: the
   row leads with the time (the name stays in the VoiceOver label). `ReminderFormat.days` (visible
   text) still shows "Weekdays", "Weekends".

## Defaults taken

- Out-of-month days are told apart by the ring only (0.85 opacity), never by text colour.
  Note: `Color.secondary` is NOT opaque (about 60 % alpha); it is no longer used for grid text.
- Day sheet state icon is `.primary` for done and not done; the symbol shape carries the state.
- Month title uses the standalone month name; day labels keep the format-context name.
- QA tests that expected "Weekdays"/"Weekends" in the row label may need `contains` checks with
  full names (UI tests not touched).
