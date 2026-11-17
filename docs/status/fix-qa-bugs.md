# fix-qa-bugs — status

Branch `ph/fix-qa-bugs`. Owned: `App/Habitat/**`, `project.yml`, `HabitatKit/**`, this file.
Nothing here was run in a simulator (the QA simulator belongs to QA and creating a throw-away
one was refused by the permission system), so the audit fixes are unverified: QA must re-run the
four audits and drop their `XCTExpectFailure` wrappers.

## Step 1: QA bugs (docs/status/qa-p3p4.md)

1/4 Contrast: goal text, streak icon, "Show archived" label, "Archived" header and the empty
    state description now use `.primary` (no secondary/tertiary text on the Habits screen).
2   Editor Dynamic Type: no fixed font sizes exist; the segmented goal picker (does not scale
    with Dynamic Type) became an inline picker. **Test impact**: `habits.editor.goalKind` is no
    longer a segmented control; QA must tap `app.buttons["Times a week"]` instead of
    `app.segmentedControls[...]` (HabitsListTests.swift:65).
3   Week: day cells are exactly 44x44 with a 44x44 outer frame; the chevrons are icon-only
    buttons with a 44x44 frame and content shape.
5   `-seed <unknown>` is logged (OSLog, category `launch`) and ignored; the store starts empty.
    The kit's `HabitatStore.prepare` still throws (its tests expect it); the app catches it.
6   `habits.empty.add` was already set on the button; the container now uses
    `accessibilityElement(children: .contain)` so the child id is exposed.
7   `habits.showArchived` is on the `Toggle` itself (label is a `Text` inside it). Tapping the
    centre of the row may still not flip the switch (system behaviour); the switch is at the
    trailing edge. Not verified.
8   The archive `confirmationDialog` already has a `Cancel` (role `.cancel`, id
    `habits.archiveCancel` added). On this OS the dialog is presented as a popover, where the
    system omits Cancel and dismisses by tapping outside; an alert would break QA's popover test,
    so it was left. Name field: `.autocorrectionDisabled()` added (sentence capitalisation kept).

## Defaults taken

- Keep `confirmationDialog` for archive (see 8).
- Inline picker for the goal kind (see 2).

## Step 2: P6 should-fix

1 Fallback `ReminderSync` (previews only) is created once through a small holder, not per body.
2 Reminder row already stacks time/days at accessibility sizes (`AnyLayout`); nothing to do.
3 `ReminderSync.markDone` keeps the refused-toggle error after the re-plan (a successful re-plan
  used to clear it at once).
5 "No active habits" text has id `reminders.editor.noHabits`; `reminders.editor.habit` is the
  picker only. Updated `docs/accessibility-ids.md` and `docs/status/p6.md`.
4 (unit tests for MarkDoneTarget, sections, ReminderFormat) is part of step 4.
