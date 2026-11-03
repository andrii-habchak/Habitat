# Habitat — decisions

Settled by the owner unless marked "default" (proposed, pending a yes).

| Id | Decision |
|----|----------|
| D1 | Name **Habitat** (iOS search for "habit"). Public repo `andrii-habchak/Habitat`. |
| D2 | Native iPhone app, SwiftUI + SwiftData, iOS 17.0 minimum (owner's phone runs iOS 26.6.1). |
| D3 | Free distribution: no paid developer account; personal-team signing for the device. |
| D4 | Week view = current calendar week Monday–Sunday, swipe to previous weeks. |
| D5 | Weekly goal colour: green when met; red only when the target is unreachable or the week is over; neutral/amber while still reachable. |
| D6 | Included in v1: streak counts per habit, JSON export/import. |
| D7 | Home-screen widget is stage 2. |
| D8 | Local builds are the gate (no hosted CI). Agents test in the simulator before the owner tests on a device. |
| D9 | default: bundle id `io.github.andrii-habchak.Habitat`. |
| D10 | default: green/red applies to the week view and the list's weekly progress; the month donut uses habit colours only. |
| D11 | Standing permission to commit and push to origin without asking, as in the owner's other repos. |
| D12 | The owner's branch guard refuses commits on and pushes to `main`. The orchestrator works on branch `integration` and pushes that branch; the owner updates `main` (`git push origin integration:main`) after each run. |
| D13 | Unattended runs: no approvals during a session. Open questions take a default and are listed in `docs/STATUS.md` "Decisions for owner" (PLAN §11). |
| D14 | default: no licence file until the owner chooses one (public repo, all rights reserved meanwhile). |
| D15 | default: no iOS 17 simulator runtime download; the minimum is enforced by availability checks. |
