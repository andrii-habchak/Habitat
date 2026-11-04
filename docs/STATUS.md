# Habitat — status

## Now

Run 1 ended (STOP, 2026-11-04 02:00). P0-P7 are merged on `integration` (fast gate green). QA of P3+P4 is parked on `ph/qa-p3p4`, not merged. QA of Month, Reminders and Settings has not run.

## Phases

| Id | Phase | State |
|----|-------|-------|
| P0 | Scaffold | merged, shell QA passed (14 UI tests, audits green) |
| P1 | HabitatCore | merged (84 tests, 97.8 % coverage) |
| P2 | HabitatData | merged (131 package tests, HabitatData 90.6 % coverage) |
| P3 | Habit list | merged (QA pending) |
| P4 | Week view | merged (QA pending) |
| P5 | Month view | merged (QA pending) |
| P6 | Reminders | merged (QA pending) |
| P7 | Settings, export/import, polish | reduced scope merged (no icon; QA pending) |
| S2 | Widget (stage 2) | not started |

## In flight

- Nothing running. QA P3+P4 finished: `ph/qa-p3p4` (f02757e, 0ce89ab) pushed, NOT merged (it was cut before the hooks/P5/P6/P7 merges, only touches App/HabitatUITests and docs/status/qa-p3p4.md). `gate.sh full` passed on that branch: 39 tests, 4 wrapped in non-strict XCTExpectFailure for the audit bugs below. No screenshot pass was done.

## Open items

- QA P3+P4 bugs (details in `docs/status/qa-p3p4.md`, branch `ph/qa-p3p4`): (1) Habits list audit "Contrast nearly passed"; (2) habit editor audit "Dynamic Type font sizes partially unsupported"; (3) Week with data audit "Hit area is too small"; (4) Habits empty state audit "Contrast nearly passed"; (5) `-seed <unknown>` crashes the app (test arg only); (6) `habits.empty.add` id not exposed; (7) `habits.showArchived` id on the whole row, tap centre does not toggle; (8) archive confirmation has no Cancel button, name field autocorrect altered input ("StretchI'm"); remove the XCTExpectFailure wrappers once fixed.
- Next run: merge `ph/qa-p3p4` into `integration` (resolve in App/HabitatUITests only), then QA round for Month, Reminders, Settings that also updates the shell tests (`month.screen`, `reminders.screen`, `settings.screen`), then fix bugs, then `gate.sh full`.

- P6 review should-fix, not done: (1) `RemindersView.swift:14` fallback ReminderSync allocated per body evaluation (previews only); (2) reminder row time/days HStack should stack at accessibility sizes; (3) `ReminderSync.markDone` refused-toggle error is cleared immediately (dead branch); (4) no unit tests for MarkDoneTarget/RemindersViewModel.sections/ReminderFormat (needs a test target or moving to HabitatKit: P7); (5) `reminders.editor.habit` id used for both picker and the "No active habits" text.
- `-fakeNotifications` always reports authorized, so UI tests cannot reach the denied-permission banner (needs a LaunchOptions/HabitatKit change).
- Notification smoke test (PLAN §7) not written: needs the real scheduler and the system permission alert, no pinned -today.
- `gate.sh full` is red on `integration` until QA updates the shell UI tests from `<tab>.placeholder` to the real screen ids (`habits.screen` already merged; week/month/reminders follow). Fast gate is green.
- No app unit-test target (needs `project.yml` change): view models and pure builders (HabitWeekRow.make, MonthCellBuilder, DonutGeometry, HabitFormat) are untested outside QA XCUITests.
- P3 reviewer notes not done: row layout at AX3+ sizes is not adapted (long names squeeze the streak counter).
- P2 review should-fix, not done: (1) no test forces a failing save, so `context.rollback()` in `DocumentStore.save()` is untested; (2) `DocumentStore.swift:43` export orders habits by sortOrder only, add tie-break (createdDaySerial, id); (3) merge validates a new reminder against the file's stale copy of an existing reminder id (conservative); (4) `UserNotificationScheduler.add` can leave a partial set pending on error, P6 should re-plan on error; (5) `ReminderModel.value` preconditionFailure on corrupt stored time; (6) no test for range queries dropping days before created day.
- P2 defaults worth the owner's eye: merge keeps the store's record on id conflicts and aborts on the first reminder clash (default 8); general reminder notification body is "Reminder" (default 12).
- Brief notes for later phases (P1 review): P5 wants a fixed 6-row month grid (`Month.grid` returns 4-6 rows, pad in UI); P2 must filter completions after an archive day for donuts and, on import-merge, validate reminder clashes against the existing store, not only within the file; P2/P6 must replace all pending notification requests on each re-plan.
- Cleanup: stray untracked `.run/wt/p0fix/App/HabitatUITests/TmpShots.swift` (QA screenshot helper; delete refused by a hook, not on any branch). Delete the worktree by hand.
- QA could not use the simulator control tool (no access response); it used `xcrun simctl`. Only the Habits tab was screenshotted.

## Decisions for owner

The owner cannot answer during a run. Each row: what was decided by default, and how to change it.
Denied actions (permission, classifier, hook) are listed here with the exact command.

| # | Date | Question / blocked action | Default taken | If you disagree |
|---|------|---------------------------|---------------|-----------------|
| 1 | 2026-11-03 | Licence for the public repo | none | add a LICENSE |
| 2 | 2026-11-03 | iOS 17 simulator runtime | not installed | install it in Xcode, run `scripts/gate.sh full` on it |
| 3 | 2026-11-03 | `.claude/settings.json` (clock guard hook, allowlist) is not in the repo, though NEXT.md says it is committed | not created (PLAN §11: agents never change settings); the clock is enforced by the orchestrator only | commit `.claude/settings.json` with the `deadline-guard.sh` PreToolUse hook before the next run |
| 4 | 2026-11-03 | P0 implementer's `rm -rf build.noindex Habitat.xcodeproj` (clean rebuild) was refused by a local PreToolUse hook: "target is outside ~/IdeaProjects/b2spin, the Claude scratch area and $TMPDIR" | not retried; gate run incrementally | widen the hook's allowed paths to include this repo, or clean `build.noindex/` by hand |
| 5 | 2026-11-04 | P1 default: two general reminders at the same time with overlapping weekdays clash even if their labels differ ("Water" and "Stretch" both 08:00 Mon are rejected) | clash regardless of label (literal "no target" reading) | treat the label as the target: change `Reminder.swift` duplicate check, update tests (P6 only) |
| 6 | 2026-11-04 | P1 default: a weekly habit's creation week counts like any other, so a past creation week with c < N shows red when swiping back | no special case | add a creation-week exemption in `WeeklyStatus` |
| 7 | 2026-11-04 | P6 reviewer's `git clone ... && git merge --no-commit integration` into the scratch folder was refused by the permission system | not retried; conflict check done by file-set analysis, then merged by the orchestrator (clean, fast gate PASS) | allow scratch-folder clones for reviewers |

## Run log

Newest first. One block per run: start, deadline, what merged, what was parked, clock state
at the end.

### Run 1 — started Tue 2026-11-03 23:12 CET, deadline Wed 2026-11-04 01:59 CET

- Preflight green, QA simulator `Habitat-QA` created. Usage at start: 5-hour 12 %, weekly 26 %.
- Committed the owner's pending hand-off/script edits, then dispatched P0.
- P0: implementer, reviewer (APPROVE, 4 should-fix, all fixed in 13ca58b), merged `--no-ff`, fast gate PASS (23:24).
- Dispatched P1 and P0 shell QA in parallel at 23:25.
- P0 shell QA merged (14 UI tests pass on `Habitat-QA`; Month audit bug found, fix dispatched). P1 implemented (97.8 % coverage), in review.
- P1 reviewed (APPROVE, 12/12 mutants killed), review fixes in 5b3d4aa, merged, fast gate PASS (00:00). P2 dispatched 00:01.
- Month contrast: fix round 1 regressed all audits, round 2 (primary subtitle, 6592d02) passed `gate.sh full` (14 tests); merged, fast gate PASS (00:10). P2 implemented, in review.
- P2 reviewed (APPROVE, 13/14 mutants killed), merged, fast gate PASS (00:10). Shared wiring dispatched before P3/P4.
- Shared wiring (AppServices, Theme, container) merged, fast gate PASS (00:15). P3 and P4 dispatched in parallel at 00:17.
- P3 and P4 implemented (gate PASS each), reviewers dispatched 00:19. P5 started 00:20 in parallel (needs only P2).
- P5 implemented (gate PASS), reviewer dispatched 00:22. P6 dispatched 00:23 (needs only P2/P3-shaped data; P3 not required for the Reminders folder).
- P3 reviewed (ids convention resolved by amending docs/accessibility-ids.md; 5 fixes in 830157d), merged, fast gate PASS (00:24).
- P4 reviewed twice (page order and per-page ids fixed), merged, fast gate PASS (00:26). QA P3+P4 dispatched 00:27.
- P5 reviewed (3 contrast must-fix, fixed in 635de46), merged, fast gate PASS (00:27).
- P6 reviewed (APPROVE, 5 should-fix), merged, fast gate PASS (00:32).
- Re-plan hooks (Habits/Week/Month call `reminderSync?.replan()` after successful changes) merged, fast gate PASS (00:34). P7 started in reduced scope (00:35).
- P7 (reduced) reviewed (missing status doc + 3 small fixes), merged, fast gate PASS (00:40). All phases P0-P7 on `integration`; QA of Month, Reminders, Settings and shell-test updates still to do after QA P3+P4.
- QA P3+P4 returned at 02:00 (STOP): 39 UI tests green on `ph/qa-p3p4` with 4 expected-failure audit bugs; branch pushed, not merged. Run ended at STOP. Owner: `git push origin integration:main` when happy.
