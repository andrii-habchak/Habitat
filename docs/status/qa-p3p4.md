# QA P3 (Habits) + P4 (Week) — status

Branch `ph/qa-p3p4`. `scripts/gate.sh full`: PASS, 39 UI tests, 0 failures (~520 s).

## Tests

- `HabitsListTests` (12): seeded rows with goal and streak (`typical`); empty state and add;
  add with name, colour and weekly goal 4; empty and blank name validation; edit rename;
  archive cancel; archive, show archived, unarchive; reorder via Edit; streak captions from
  `streaks` (10 d, 3 d, 4 wk); toggling in Week changes the streak in Habits (3 -> 4 days);
  audits for the list and the editor.
- `WeekViewTests` (13): title `2 - 8 Nov 2026` and `week.screen`; today column; headers;
  toggle updates cell value and `week.progress` count; future days (4-8 Nov) disabled and
  not toggleable; previous week by chevron and by swipe with unique ids; weekly status
  met / in progress / failed; daily habits have no progress; streak values; empty state; audit.
- `TabShellTests`, `ShellSmokeTests`: Habits and Week use `<tab>.screen`; seed test uses `typical`.

## Bugs (not fixed; app code is not QA-owned)

1. BUG-QA34-1 (should-fix): Habits list fails `performAccessibilityAudit()`: "Contrast nearly
   passed" (`typical` seed). Test `testAuditHabitsList` is a non-strict expected failure.
2. BUG-QA34-2 (should-fix): editor sheet fails the audit: "Dynamic Type font sizes are partially
   unsupported". `testAuditHabitEditor`, expected failure.
3. BUG-QA34-3 (should-fix): Week with data fails the audit: "Hit area is too small" (likely the
   day cells or chevrons). `testAuditWeekWithData`, expected failure.
4. BUG-QA34-4 (should-fix): Habits empty state fails the audit: "Contrast nearly passed"
   (`TabShellTests.testAuditHabits`, expected failure).
5. Low: `-seed does-not-exist` crashes the app (unknown fixture is not handled); only a
   test-launch argument.
6. Low: `habits.empty.add` is not exposed (the ContentUnavailableView reports `habits.empty` for
   its children); the button is found by label "Add habit" (matches the toolbar button too).
7. Low: `habits.showArchived` is on the whole row, so tapping its centre does not toggle; the
   switch is at the right edge. The toggle disappears once nothing is archived.
8. Low: the archive confirmation is a popover with no Cancel button here; dismiss by tapping
   outside. The name field autocorrects: typing "Stretch" then tapping a colour produced
   "StretchI'm" in one run (tests type a trailing space). Consider disabling autocorrection.
9. Note: `habits.editor.color.<hex>` uses palette hex (E5484D for Red), not the seed colours.

## Not done

- Screenshots (light, dark, XXXL) of Habits, editor and Week: not taken, the run deadline
  (01:59) passed while fixing tests. Needs a follow-up pass.
- Month and Reminders still use placeholders; tests unchanged for P5/P6.
