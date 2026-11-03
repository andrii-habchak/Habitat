import HabitatCore
import HabitatData
import Observation
import SwiftUI

/// Keeps the pending notification requests in line with the stored reminders, habits and
/// completions (PLAN §2: re-planned on app open and on every toggle), and tracks the
/// notification permission.
///
/// Other screens call `replan()` after anything that changes what should be delivered
/// (a habit toggled, created, archived or renamed). Read it with
/// `@Environment(\.reminderSync) private var reminderSync` and call `reminderSync?.replan()`.
@MainActor
@Observable
final class ReminderSync {
    /// `nil` until the first check.
    private(set) var authorization: NotificationAuthorization?
    /// Text of the last failed re-plan (after its retry), `nil` once one succeeds.
    private(set) var lastErrorMessage: String?

    @ObservationIgnored let scheduler: any NotificationScheduling
    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherPass = false

    init(services: AppServices, scheduler: any NotificationScheduling) {
        self.services = services
        self.scheduler = scheduler
    }

    /// The fake scheduler for `-fakeNotifications` (UI tests never see a system prompt),
    /// the system one otherwise.
    static func makeScheduler(for launchOptions: LaunchOptions) -> any NotificationScheduling {
        launchOptions.fakeNotifications ? FakeNotificationScheduler() : UserNotificationScheduler()
    }

    /// Whether the system notification centre is in use (not the fake).
    var usesSystemNotifications: Bool { scheduler is UserNotificationScheduler }

    // MARK: - Re-planning

    /// Re-plans in the background. Calls while a pass runs are folded into one more pass.
    func replan() {
        if running != nil {
            needsAnotherPass = true
            return
        }
        running = Task { [weak self] in
            await self?.runPasses()
        }
    }

    /// Re-plans and waits until the pending requests are replaced.
    func replanAndWait() async {
        replan()
        await running?.value
    }

    /// App launch and every return to the foreground.
    func sceneDidBecomeActive() {
        replan()
        Task { await refreshAuthorization() }
    }

    private func runPasses() async {
        repeat {
            needsAnotherPass = false
            await replanWithRetry()
        } while needsAnotherPass
        running = nil
    }

    /// The system scheduler can leave a partial set pending when one `add` fails, so a
    /// failed pass is run once more (it removes everything first).
    private func replanWithRetry() async {
        for _ in 1...2 {
            do {
                try await replaceAllPending()
                lastErrorMessage = nil
                return
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func replaceAllPending() async throws {
        let today = services.today
        let reminders = try services.reminderRepository().all()
        let habits = try services.habitRepository().all()
        let completions = try services.completionRepository()
            .completions(from: today, through: today.adding(days: ReminderPlanner.windowDays))
        try await NotificationSync.replaceAllPending(
            using: scheduler,
            reminders: reminders,
            habits: habits,
            completions: completions,
            now: services.clock.now()
        )
    }

    // MARK: - Permission

    func refreshAuthorization() async {
        authorization = await scheduler.authorizationStatus()
    }

    /// Shows the system prompt if the user was never asked; re-plans afterwards.
    func requestAuthorizationIfNeeded() async {
        await refreshAuthorization()
        guard authorization == .notDetermined else { return }
        _ = try? await scheduler.requestAuthorization()
        await refreshAuthorization()
        replan()
    }

    // MARK: - "Mark done" action

    /// Marks the habit done on `day` (never un-marks it) and re-plans, so the other
    /// reminders of that habit on that day are dropped.
    func markDone(habitID: UUID, day: DayKey) async {
        let completions = services.completionRepository()
        do {
            if try !completions.isDone(habitID: habitID, day: day) {
                try completions.toggle(habitID: habitID, day: day)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        await replanAndWait()
    }
}

private struct ReminderSyncKey: EnvironmentKey {
    static let defaultValue: ReminderSync? = nil
}

extension EnvironmentValues {
    /// Set by `HabitatApp`; `nil` in previews.
    var reminderSync: ReminderSync? {
        get { self[ReminderSyncKey.self] }
        set { self[ReminderSyncKey.self] = newValue }
    }
}
