# QA P5 (Month) + P6 (Reminders) + P7 (Settings) — status

Branch `ph/qa-p5p7`. Base: `integration` at 2abb6c0 (includes the P3/P4 QA tests). Today pinned to
2026-11-03, seed `typical` unless noted. See the end of this file for the gate result.

## Tests

- `MonthViewTests` (16): title; Monday-first grid; donut `done/active` values for several days
  (3/5, 4/5, 3/5, 3/5, future 0/5); today marker; month navigation previous/next/3 forward;
  filter chips (All default, single habit = `1/1` or `0/1`, back to All); day sheet lists habits
  with state; toggle updates the donut and is undoable; past day toggle; future day toggles;
  sheet toggle shows in the Week tab; filter + sheet; empty store; audits (grid, day sheet).
- `RemindersTests` (19): seeded rows; empty state and add; add general (label, weekdays);
  add habit reminder; no weekday selected; duplicate general (message names the clash, nothing
  stored); disjoint weekdays at the same time accepted; partial overlap rejected then fixed;
  duplicate habit reminder; edit label and weekdays; unchanged edit does not clash with itself;
  cancel edit; delete from editor; swipe delete; recreate after delete; no permission banner;
  audits (list, editor).
- `SettingsTests` (7): export shows the share sheet and no `settings.exportError` (typical and
  empty store, repeatable after dismissing); about (name, version, privacy note); no stray
  error/result on launch; import opens the file picker and Cancel changes nothing; audit.
- `ScreenshotTests`: skipped unless `TEST_RUNNER_HABITAT_SHOTS=1`; writes the PNGs below.
  Dark needs `xcrun simctl ui <udid> appearance dark` first and `TEST_RUNNER_HABITAT_SHOTS_VARIANT=dark`
  (the `-AppleInterfaceStyle Dark` launch argument does not switch the scheme here).
- Shell tests now use `<tab>.screen` for all five tabs; Month and Settings shell audits are
  non-strict expected failures. `HabitsListTests` taps the goal kind with `app.buttons["Times a week"]`
  (works for segmented and inline pickers).

Screenshots: `docs/status/screenshots/qa-p5p7/<tab>-<light|dark|xxxl>.png` (15 files).

## Bugs (app code is not QA-owned; wrappers are non-strict XCTExpectFailure, remove when fixed)

1. BUG-QA57-1 (must-fix) Month: the title reads "M11 2026" and the day cell labels read
   "Mon 26 M10, 0 of 5 habits done" instead of "November 2026" / "Monday 26 October ...".
   Month and weekday names are not resolved (`MonthSymbols`). `month.title`, `month.day.<date>`.
   Tests: `testMonthTitleNamesTheMonthAndYear`, `testMondayFirstGrid`.
2. BUG-QA57-2 (low) Month day sheet: toggles for a future day are not exposed as disabled
   (`isEnabled` is true), though tapping does not change the state. `month.daySheet.toggle.<id>`.
3. BUG-QA57-3 (should-fix) Month grid audit: "Contrast failed" (`typical` seed). `testAuditMonthWithData`.
4. BUG-QA57-4 (should-fix) Month day sheet audit: "Contrast failed". `testAuditDaySheet`.
5. BUG-QA57-5 (should-fix) Reminders list audit: "Contrast nearly passed". `testAuditRemindersList`.
6. BUG-QA57-6 (should-fix) Reminder editor audit: "Contrast failed". `testAuditReminderEditor`.
7. BUG-QA57-7 (should-fix) Settings audit: "Contrast nearly passed". `testAuditSettings`,
   `TabShellTests.testAuditSettings`.
8. BUG-QA57-8 (should-fix) Month empty state (shell, no seed) audit: "Contrast failed".
9. BUG-QA57-9 (low) Reminders: the row label uses the summary words ("Weekdays", "Weekends",
   "Every day") rather than full day names, and times in the device format ("8:00", "21:00").
   docs/status/p6.md says VoiceOver reads full day names; only the editor chips do. Acceptable;
   the tests accept the summary.
10. BUG-QA57-10 (low) Reminders at XXXL: section header and row title repeat the habit name
    ("Read" / "Read"), costing a screen of height. Visual only.
11. BUG-QA57-11 (low) Month dark mode: out-of-month days and not-done segments are very faint on
    the black background (the whole first row and last row nearly vanish). Visual only.

Visual notes: all five tabs are readable in light, dark and XXXL; Month filter chips scroll
horizontally and are clipped at the right edge (expected); Week turns into a vertical list at
XXXL; Settings rows wrap ("Export data") and the About rows scroll under the tab bar.

## Not tested

- "Mark done" notification action (needs the real scheduler and a delivered notification),
  the notification smoke test, and the permission-denied banner (`-fakeNotifications` is always
  authorized).
- Habit-kind reminder clash at a custom time and the time picker (the picker is not driven;
  clashes use the default 09:00).
- Import with a real file (system picker is out of process): only open and cancel.
- The share sheet's actual file content.

## Re-verification after the fix lanes (integration 4266bcd)

Method: every `XCTExpectFailure` was made strict for one full run; a wrapper whose audit now
passes fails with "expected failure but none recorded". Fixed wrappers were removed, the others
went back to non-strict. The audit messages below are those of the earlier runs; the strict run
confirmed each still records a failure.

| Bug | State | Note |
|-----|-------|------|
| BUG-QA34-1 Habits list audit | fixed | wrapper removed, audit passes |
| BUG-QA34-2 Habit editor audit | open | "Dynamic Type font sizes partially unsupported" |
| BUG-QA34-3 Week audit | open | "Hit area is too small" |
| BUG-QA34-4 Habits empty state audit | open | "Contrast nearly passed" (shell test) |
| BUG-QA57-1 Month names | fixed | title "November 2026", labels "Monday 26 October, ..." asserted directly |
| BUG-QA57-2 future-day toggles | fixed | `isEnabled` is false, wrapper removed |
| BUG-QA57-3 Month grid audit | open | "Contrast failed" |
| BUG-QA57-4 Month day sheet audit | open | "Contrast failed" |
| BUG-QA57-5 Reminders list audit | open | "Contrast nearly passed" |
| BUG-QA57-6 Reminder editor audit | open | "Contrast failed" |
| BUG-QA57-7 Settings audit | open | "Contrast nearly passed" (also shell test) |
| BUG-QA57-8 Month empty state audit | open | "Contrast failed" (shell test) |
| BUG-QA57-9 row label summary words | fixed | rows now spell out the days |
| BUG-QA57-10 duplicated habit name | fixed | habit rows no longer repeat the section title (XXXL) |
| BUG-QA57-11 Month dark faintness | fixed visually | dark segments and out-of-month days are readable |
| BUG-QA-REG-1 (should-fix) | open | `habits.empty` is no longer exposed: the empty state container reports `habits.screen` (element tree: `habits.screen` holds "No habits yet" and `habits.empty.add`). Repro: launch `-seed empty`, look up `habits.empty`. The test finds the empty state by text and `habits.empty.add`. |

Ids checked: `habits.empty.add` (works), `settings.notifications` (present, test added),
`reminders.editor.noHabits` (test added), `habits.archiveCancel` (not reachable: the archive
confirmation is a popover without a reachable Cancel button in the test).

Visual (retaken, 15 files): Month dark is now readable; Reminders at XXXL stacks time and days
without the repeated name; Settings at XXXL wraps "Export data" and hyphenates the
"Notification settings" row ("Notif-ication"), low; Month still leaves empty space under the grid.

## Round 3 (after ph/fix-qa57 at 0b1ba07)

A strict run (all wrappers strict) found one fixed audit and one regression-looking failure; the
rest of the wrappers still record failures.

| Bug | State |
|-----|-------|
| BUG-QA57-5 Reminders list audit | fixed (wrapper removed) |
| BUG-QA34-2 Habit editor audit | open: "Dynamic Type font sizes partially unsupported" |
| BUG-QA34-3 Week audit | open: "Hit area is too small" |
| BUG-QA34-4 Habits empty state audit (shell) | open: "Contrast nearly passed" |
| BUG-QA57-3 Month grid audit | open: "Contrast failed" |
| BUG-QA57-4 Month day sheet audit | open: "Contrast failed" |
| BUG-QA57-6 Reminder editor audit | open: "Contrast failed" |
| BUG-QA57-7 Settings audit | open: "Contrast nearly passed" |
| BUG-QA57-8 Month empty state audit (shell) | open: "Contrast failed" |
| BUG-QA-REG-1 `habits.empty` id | open (low): debug tree shows `ScrollView identifier 'habits.screen'` containing `StaticText 'No habits yet'` and `Button 'habits.empty.add'`; no element has `habits.empty` in any query type. Test finds the empty state by text and `habits.empty.add`. |

Visual findings (screenshots retaken, 21 files incl. `habits-empty-*` and `month-empty-*`):
- BUG-QA57-12 (should-fix): the Habits empty state "Add habit" button is black text on a saturated blue
  fill (`habits-empty-xxxl.png`, also light): low contrast.
- BUG-QA57-13 (should-fix): empty Month days (no habits) are drawn as thick white rings in dark mode
  (`month-empty-dark.png`), visually louder than rings with data; expected a thin line.
- BUG-QA57-14 (low): Month title hyphenates at XXXL ("No-vember 2026"); it needs `minimumScaleFactor` or
  a line limit. Settings at XXXL also hyphenates "Notif-ication settings" (low).
- Habits list, Week (light and dark), Month with data (light, dark) and Reminders look correct; Month
  out-of-month days are no longer dimmed (as intended).
