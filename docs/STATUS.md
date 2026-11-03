# Habitat — status

## Now

Run 1 in progress on branch `integration`. Planning docs committed; P0 (scaffold) dispatched.

## Phases

| Id | Phase | State |
|----|-------|-------|
| P0 | Scaffold | merged; shell QA tests merged; Month audit fix in flight (`ph/p0-fix-month`) |
| P1 | HabitatCore | in flight (`ph/p1-core`) |
| P2 | HabitatData | not started |
| P3 | Habit list | not started |
| P4 | Week view | not started |
| P5 | Month view | not started |
| P6 | Reminders | not started |
| P7 | Settings, export/import, polish | not started |
| S2 | Widget (stage 2) | not started |

## In flight

- P0 Month contrast fix — branch `ph/p0-fix-month`, worktree `.run/wt/p0fix`, implementer; QA re-verify after.
- P1 review — fresh reviewer on `ph/p1-core` (8ec3401).

## Open items

- Month tab fails `performAccessibilityAudit()` (contrast on the placeholder text); `testAuditMonth` has an expected-failure wrapper until fixed (QA, c9e0804).
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

## Run log

Newest first. One block per run: start, deadline, what merged, what was parked, clock state
at the end.

### Run 1 — started Tue 2026-11-03 23:12 CET, deadline Wed 2026-11-04 01:59 CET

- Preflight green, QA simulator `Habitat-QA` created. Usage at start: 5-hour 12 %, weekly 26 %.
- Committed the owner's pending hand-off/script edits, then dispatched P0.
- P0: implementer, reviewer (APPROVE, 4 should-fix, all fixed in 13ca58b), merged `--no-ff`, fast gate PASS (23:24).
- Dispatched P1 and P0 shell QA in parallel at 23:25.
- P0 shell QA merged (14 UI tests pass on `Habitat-QA`; Month audit bug found, fix dispatched). P1 implemented (97.8 % coverage), in review.
