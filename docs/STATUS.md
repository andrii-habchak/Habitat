# Habitat — status

## Now

Run 1 in progress on branch `integration`. Planning docs committed; P0 (scaffold) dispatched.

## Phases

| Id | Phase | State |
|----|-------|-------|
| P0 | Scaffold | merged, shell QA passed (14 UI tests, audits green) |
| P1 | HabitatCore | merged (84 tests, 97.8 % coverage) |
| P2 | HabitatData | merged (131 package tests, HabitatData 90.6 % coverage) |
| P3 | Habit list | not started |
| P4 | Week view | not started |
| P5 | Month view | not started |
| P6 | Reminders | not started |
| P7 | Settings, export/import, polish | not started |
| S2 | Widget (stage 2) | not started |

## In flight

- Shared wiring (container, theme, ids) — branch `ph/shared-wiring`, worktree `.run/wt/wiring`, before P3/P4 lanes.

## Open items

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
