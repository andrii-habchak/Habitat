# Habitat — plan

## 1. Product

iPhone habit tracker. Three main views: month calendar (donut per day), habit list, week view.
Reminders (general and per habit). Streaks. JSON export/import. Home-screen widget is stage 2.
Local only: no account, no backend. Public repo, free app.

## 2. Domain rules

- **Day** = calendar date without time (`DayKey`, `yyyy-MM-dd`). No time-of-day in completions,
  so time zone and DST cannot move a completion to another day.
- **Week** = Monday–Sunday, fixed (`firstWeekday = 2`), independent of the device locale.
  Week view shows the current calendar week; swipe back for previous weeks.
- **Goal** = `daily` (every day, i.e. 7 per week) or `timesPerWeek(N)`, N in 1...7.
- **Weekly status** of a habit for a week, with `c` = days done, `N` = target, `r` = days left
  including today (0 for a finished week):
  - `met` (green): `c >= N`.
  - `failed` (red): `c < N` and `c + r < N` (target unreachable, or the week is over).
  - `inProgress` (neutral/amber): `c < N` and `c + r >= N`.
  Red never shows just because the week started.
- **Streak**: daily habit = consecutive days done up to today (today not yet done does not break
  it); weekly habit = consecutive `met` weeks, counting the current week once it is `met`.
- **Habit lifecycle**: created on a day (counts from then), can be archived (kept in history,
  hidden from lists, excluded from donuts after the archive day).
- **Reminders**: `general` (label, time, weekdays) or `habit(id)` (time, weekdays); many of each.
  Duplicate = same kind, same target, same time and an overlapping weekday set → rejected with
  a message naming the clashing reminder. A habit reminder is not delivered when the habit is
  already done that day (re-planned on app open and on every toggle; rolling window of 14 days,
  never more than 60 pending requests). Notification action: "Mark done".
- **Export**: one JSON file, `schema: 1`, habits + completions + reminders. Import validates the
  schema and offers merge or replace. Round trip must be lossless.

## 3. Architecture

- `HabitatKit` local package, two targets: `HabitatCore` (pure value types and logic, no
  SwiftData, no UI) and `HabitatData` (SwiftData models, repositories, import/export,
  `NotificationScheduling` protocol with a real and a fake implementation).
- Time is injected (`Clock` protocol). The app reads launch arguments for tests:
  `-uiTesting` (in-memory store), `-seed <fixture>`, `-today yyyy-MM-dd`, `-fakeNotifications`.
- UI is SwiftUI with Observation (iOS 17). Every interactive element has an accessibility
  identifier `<screen>.<element>[.<id>]` (convention fixed in phase 0).
- App Group and widget target are stage 2. Do not add them earlier.
- Bundle id `io.github.andrii-habchak.Habitat`, deployment target iOS 17.0.

## 4. Views and acceptance criteria (R-IDs are cited in tests)

- **R-LIST** Habit list: add, edit (name, color, goal), archive, reorder; shows goal and streak.
- **R-WEEK** Week view: header = habit name; 7 columns Mon–Sun; tap toggles done/not done; future
  days disabled; weekly-goal habits show `c/N` and the weekly status colour (§2); previous weeks
  by swipe; today highlighted.
- **R-MONTH** Month view: Monday-first grid; each day has a donut, one segment per active habit
  in its own colour (filled = done, dim = not done); tap a day opens a sheet to toggle that
  day's habits; filter chips by habit (single habit = single ring); month navigation.
- **R-REM** Reminders: create/edit/delete general and per-habit reminders; duplicate rule (§2);
  permission denied state is explained; notification action marks done.
- **R-STREAK** Streak counts on list and week view.
- **R-DATA** Export/import as in §2; invalid files give a readable error and change nothing.
- **R-A11Y** Dark mode, Dynamic Type up to accessibility sizes, VoiceOver labels, passes
  `performAccessibilityAudit()`.

## 5. Phases (stage 1)

Pipeline estimate = implement + review + fix + QA + merge, in minutes.

| Id | Phase | Depends | Est. | Parallel |
|----|-------|---------|------|----------|
| P0 | Scaffold: `project.yml`, package skeleton, tab shell, `scripts/gate.sh`, lint config, accessibility-id convention, launch-argument plumbing, `.gitignore`, README | — | 35 | — |
| P1 | `HabitatCore`: day/week/month math, goal + weekly status, streaks, reminder validation + planner, export schema, with tests | P0 | 45 | — |
| P2 | `HabitatData`: SwiftData models, repositories, seed fixtures, JSON import/export, fake scheduler, tests | P1 | 45 | — |
| P3 | Habit list + editor (R-LIST) | P2 | 45 | with P4 |
| P4 | Week view (R-WEEK, R-STREAK on week) | P2 | 40 | with P3 |
| P5 | Month view, donut, filter, day sheet (R-MONTH) | P2 | 55 | after P3/P4 |
| P6 | Reminders: UI, scheduler, validation, notification action (R-REM) | P3 | 60 | — |
| P7 | Settings, export/import UI, streak polish, dark mode, Dynamic Type, a11y audit, icon (R-DATA, R-A11Y) | P3-P6 | 55 | — |

Stage 2 (not started): home-screen widget (today's habits, interactive toggle via App Intent,
needs an App Group — verify the free personal team allows it before designing).

Disjoint folders for parallel lanes: `Features/Habits`, `Features/Week`, `Features/Month`,
`Features/Reminders`. Shared files (`project.yml`, tab shell, `HabitatKit/Package.swift`,
design tokens) are changed on `main` by the orchestrator's dispatch of a one-line shared-file
change to an implementer **before** the lanes that need them start. Max 2 implementers at once.

## 6. Pipeline per phase

1. **Implementer** (opus/sonnet per §9) in its own worktree: reads the docs, implements, writes
   unit tests that cite R-IDs, runs `scripts/gate.sh fast`, commits on `ph/<id>-<slug>`, writes
   `docs/status/<id>.md`, returns a short report.
2. **Reviewer** (fresh, read-only): diff vs acceptance criteria and `docs/PLAN.md` rules; re-runs
   the gate; checks tests are meaningful (not only happy path) and cite R-IDs; checks the
   branch touches only owned paths; returns `must-fix` / `should-fix` with file:line.
3. **Fix**: `must-fix` goes back to the **same implementer** (SendMessage, keeps its context).
   Reviewer re-checks only those items (same reviewer, SendMessage). At most 2 rounds; after
   that, or if a finding is a design problem, a **fresh** implementer takes the report.
   `should-fix` that is not done goes to `docs/STATUS.md` "Open items".
4. **QA** (fresh) for phases with UI (P3-P7) and for P0's shell: writes XCUITests from the
   acceptance criteria, runs them on `Habitat-QA`, takes screenshots (light, dark, large
   Dynamic Type), reports bugs. Bugs go to the implementer, then QA re-verifies. P1 and P2 have
   no QA step; their reviewer also runs a mutation-style spot check (break a rule, see a test
   fail).
5. **Merge**: orchestrator merges `--no-ff` into the long-lived branch `integration` (never
   commits on local `main` and never pushes `main`: the owner's branch guard refuses both),
   runs `scripts/gate.sh fast`, then pushes `integration`. After merging parallel lanes it runs
   `scripts/gate.sh full` once. The owner fast-forwards `main` from `integration` after the run.
6. Orchestrator updates `docs/STATUS.md` and ticks this table.

Why these splits: the implementer keeps context for fixes and writes unit tests next to the
code. The reviewer must not be the author. QA writes UI tests from the spec so they are a
black-box check, not a mirror of the implementation.

## 7. Test strategy (agents test first; the owner tests on a device last)

| Layer | Tool | What | Who |
|-------|------|------|-----|
| Logic | Swift Testing, `swift test` (no simulator) | goal/week status table, Monday boundaries, DST and month ends, streaks, reminder duplicate/overlap, planner ≤ 60 requests, export round trip, malformed import | implementer, checked by reviewer |
| Data | Swift Testing, in-memory SwiftData | repositories, archive rules, import merge/replace, fake scheduler calls | implementer |
| UI | XCUITest on `Habitat-QA` with `-uiTesting -seed -today` | one flow per R-ID: toggle, week colours, donut segments (via accessibility values), filter, duplicate-reminder error, export/import | QA |
| Visual | simulator screenshots read by QA | light/dark, small and large iPhone, Dynamic Type XXL, empty states | QA |
| Accessibility | `performAccessibilityAudit()` | each main screen | QA |
| Static | `swiftlint --strict`, Swift 6 strict concurrency, warnings as errors | every gate | gate |
| Notification smoke | one UI test: reminder 1 minute ahead, app backgrounded, banner appears | P6 QA |

Determinism: time and data are injected, so week colours and donuts do not depend on the real
date. Coverage target: ≥ 90 % lines in `HabitatCore`, reported by the reviewer.

Not covered by agents (owner, on the iPhone, iOS 26.6.1): real notification delivery timing,
widget on the home screen (stage 2), signing with the personal team, feel and performance. Only
iOS 27.x simulator runtimes are installed, so the iOS 17 minimum is enforced by API availability
checks, not by running on 17. Optional: download an iOS 17 runtime for a final pass.

## 8. Definition of done (per phase)

Gate green on the branch and on `main` after merge; reviewer has no open `must-fix`; QA passed
(if the phase has UI); status note and `docs/STATUS.md` updated; pushed.

## 9. Models and effort

| Role | Model | Effort | Why |
|------|-------|--------|-----|
| Orchestrator (the session) | Opus 5.5 | medium | control and judgement over a long context, little code |
| P0 scaffold, P1 core, P6 reminders | opus | high | structure and rules everything depends on |
| P2-P5, P7 implementers | sonnet | medium | well-specified SwiftUI/SwiftData work |
| Reviewer | fable | high | independent, strongest read of a diff |
| QA | sonnet | medium | many tool calls, screenshots, XCUITests |
| Re-review of fixes | same reviewer | — | context kept via SendMessage |

The orchestrator passes `model` and `effort` on every dispatch from this table. If the Fable
weekly bucket is unavailable, use opus/high for reviewers.

## 11. Unattended runs (the owner cannot approve anything during a session)

- Never wait for an answer. Every open question gets a **proposed default** and is recorded in
  `docs/STATUS.md` "Decisions for owner" (question, default taken, what changes if the owner
  chooses otherwise). Work continues on the default.
- A denied action (permission prompt, classifier or hook refusal) is never retried in another
  form and never circumvented. Record it in "Decisions for owner" with the exact command and the
  reason given, then continue with other work. If a phase cannot proceed without it, park the
  phase (`wip/<id>`), say so in the hand-off, and start the next independent phase.
- Never change agent settings, hooks or permissions, and never touch anything outside the repo
  and the scratch folder. No downloads, installs or `sudo`. Prefer tools already on the Mac.
- Irreversible or outward-facing steps beyond the plan (new repos, releases, force-push, deleting
  remote branches, App Store, signing) are out of scope: list them for the owner instead.
- Pushes are limited to the `integration`, `ph/*` and `wip/*` branches of this repo. Never
  push `main`.

## 10. Run clock

The owner sets a deadline when starting a run (`scripts/kickoff.sh "YYYY-MM-DD HH:MM"`, Paris
time). `scripts/deadline.sh` prints `STATE=RUN|FREEZE|STOP MIN_LEFT=…`.

- **RUN**: start a phase only if `MIN_LEFT >= estimate (§5) + 25`.
- **FREEZE** (≤ 19 min left): no new work. Only dispatches whose prompt contains the token
  `WRAPUP` are allowed (the guard hook enforces it). In-flight agents get 5 minutes to reach a
  green commit; otherwise their work is pushed to `wip/<id>` and `main` stays green.
- **STOP** (≤ 4 min left): stop remaining agents, finish `docs/STATUS.md` and `docs/NEXT.md`,
  commit, push, end the session. The guard refuses every agent call.
- Plan usage is checked at every phase boundary; 5-hour ≥ 85 % or weekly ≥ 90 % counts as
  FREEZE.
- At FREEZE/STOP the status must record: what merged, what is in flight (branch + state), what
  was parked, the next phase with a fresh estimate, and the exact prompt for the next run.
