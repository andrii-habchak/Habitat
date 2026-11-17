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

## Round 3: fixes from the audit evidence

Source: issue text and element screenshots exported from
`wt/qa57/build.noindex/results/ui-20261117-223549.xcresult` (legacy `get object`, `expectedFailures
-> failureSummary`: message, detailedDescription, attachments). Not verified: no UI test can be run
here; QA must re-run the audits. The hit-area issue carries no element screenshot, so that element
is inferred.

| Bug | Element found | Change / status |
|-----|---------------|-----------------|
| QA34-2 Habit editor, Dynamic Type | "Save" toolbar button (confirmation action, bold, glass); Cancel passes | Label is `Text("Save").font(.body.weight(.semibold))`. May still fail if the system bar button ignores it: not fixable beyond that. |
| QA57-6 Reminder editor | The audit text is "Dynamic Type", not contrast: the "Save" toolbar button | Same change as above |
| (new in the evidence) Day sheet, Settings, Shell Settings | Day sheet "Close" button (same toolbar change); Settings: the plain text "Data stays on this device." | Explicit `.font(.body)` on that text; cause unclear (the element is fine in the screenshot), may remain |
| QA34-4 Habits empty state, contrast nearly passed | "Add habit" prominent button: white on system blue (about 4:1) | `Theme.prominentButtonTint` #2563EB (white text about 5:1) |
| QA57-5 Reminders list, contrast nearly passed | Section header "General" (system grey; `.foregroundStyle` on the header text is overridden by the system) | `.headerProminence(.increased)` (primary header), also on Settings sections and Habits "Archived" |
| QA57-3 / QA57-8 Month grid, contrast failed | The day cell "26" (out-of-month first cell). Only all-faint cells fail: its ring was thin, pastel (0.85 x 0.85 opacity) or a grey empty ring, and the audit judges a cell by its dominant colour. In-month cells with thick full-colour segments pass. | Rings are fully opaque (not-done = thin, full colour; empty = thin `.primary`); no opacity for out-of-month days (they differ by font weight only). Inference, not proven. |
| QA57-4 Month day sheet, contrast failed | Evidence shows only a Dynamic Type issue on the "Close" button (no contrast issue recorded in this run) | "Close" font as above |
| QA34-3 Week hit area | No element screenshot. Candidates: the progress and streak labels (exposed elements with id and value, about 20 pt high). Chevrons are 44 pt in the screenshot. | Both labels get the `.isStaticText` trait so they are not treated as controls. Inference, may remain. |
| BUG-QA-REG-1 `habits.empty` | `ContentUnavailableView` swallows child ids; with `.contain` the container reported `habits.screen` | Empty state built by hand as a `VStack` with `.contain`: `habits.empty` on the container, `habits.empty.add` on the button |

Defaults: the empty month ring is a stark thin `.primary` line (visual change, for the audit).
