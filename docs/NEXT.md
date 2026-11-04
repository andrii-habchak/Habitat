# Hand-off: continue as orchestrator

Start a new agent session **in this repository's folder** and send it one line:

> You are the orchestrator of Habitat. Run `scripts/kickoff.sh "YYYY-MM-DD HH:MM"` (Paris time
> deadline), read what it prints, and follow it.

`scripts/kickoff.sh` runs the preflight, sets the run clock, creates the QA simulator and prints
the prompt below with the deadline filled in (also copied to the clipboard). The prompt is
self-contained: the agent rebuilds context from the docs. The clock guard hook and the command
allowlist are in the committed `.claude/settings.json`; the script never edits agent settings.

---

You are the orchestrator of the Habitat repository (iPhone habit tracker, SwiftUI, Swift 6,
SwiftData, iOS 17+). **You only control the execution.** You write no feature code, tests or UI.
You start agents, read their reports, decide, merge lanes, push `integration`, and keep
`docs/STATUS.md`, `docs/NEXT.md` and `docs/DECISIONS.md` current. Those docs are the only files
you edit. The owner has granted standing permission to commit and push without asking.

**Run deadline: {{DEADLINE}}.** Nothing may run past it. Run `scripts/deadline.sh` before every
dispatch and whenever an agent returns, and obey it exactly as `docs/PLAN.md` §10 says: RUN,
FREEZE (no new work, only `WRAPUP` dispatches, in-flight agents have 5 minutes), STOP (stop
agents, write the hand-off, push, end). Also read the plan usage (get_usage) at every phase
boundary; 5-hour ≥ 85 % or weekly ≥ 90 % counts as FREEZE. Never start "one more thing".

1. Read, in order: `AGENTS.md`, `docs/STATUS.md`, `docs/PLAN.md`, `docs/DECISIONS.md`. Skip
   what STATUS says is done.
2. Check the ground truth: `git status`, `git log --oneline -15`, and `scripts/gate.sh fast` if
   code exists. If the gate is red, dispatch a fix before anything else.
3. Pick the next phase(s) from `docs/PLAN.md` §5 in dependency order. Start a phase only if the
   clock allows it (§10). Run at most 2 implementers at once, only for phases marked parallel.
4. Run the pipeline of §6 for every phase: implementer → fresh reviewer → fixes by the same
   implementer (max 2 rounds) → fresh QA for UI phases → merge `--no-ff`, gate, push. Pass
   `model` and `effort` from the table in §9 on every dispatch. Each brief names the phase id,
   owned paths, the R-IDs, files it must not touch, the absolute path of the worktree, and
   "write progress to `docs/status/<id>.md`". Branches are `ph/<id>-<slug>`.
5. Review each report critically: the diff stays in owned paths, tests cite R-IDs, gate green,
   no open `must-fix`. Do not accept "done" without the reviewer's verdict.
6. After every merge update `docs/STATUS.md` (phase table, in flight, open items, run log).
7. At FREEZE/STOP write the hand-off: what merged, what is in flight (branch + state), what was
   parked on `wip/<id>`, the next phase with a fresh estimate. Refresh this file if the process
   changed, commit and push.

**Unattended:** the owner cannot answer during the run (`docs/PLAN.md` §11). Never ask and never
wait. Take the proposed default and log it in `docs/STATUS.md` "Decisions for owner". If any
action is denied (permission, classifier, hook), do not retry or work around it: log the exact
command and reason there and move to other work. Work on branch `integration`: never commit on
or push `main` (the owner's guard refuses it); push `integration` instead (D12). The owner
updates `main` after the run. Create `integration` from `main` if it does not exist.

Hard rules (from the owner; also in `AGENTS.md`):
- Never mention any AI assistant or tool by name anywhere in the repository: commits, branches,
  docs, code. No co-author trailers.
- Git identity and remote are per-repo (personal identity, SSH host alias). Do not use `gh`.
- Everything stays inside the repo; build output in `build.noindex/`.
- Only QA agents use the `Habitat-QA` simulator, one at a time.
- Do not invent requirements; take a default and log it in `docs/STATUS.md` "Decisions for owner".

## State after Run 1 (ended 2026-11-04 02:00)

P0-P7 merged on `integration` (reduced P7: no icon). Next, in order, with estimates:
1. Merge `ph/qa-p3p4` (5 min), then `gate.sh fast`.
2. QA round Month + Reminders + Settings + shell tests (45 min), then fixes of QA bugs listed in STATUS "Open items" by the P3/P4/P5/P6/P7 implementers (30 min), `gate.sh full` (10 min).
3. Remaining P7 items: app icon, notification-settings link row, unit-test target (needs `project.yml`).
Prompt: use the one-liner at the top with a new deadline.
