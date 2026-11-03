import HabitatCore
import HabitatData
import SwiftData
import SwiftUI

/// Dependencies shared by every screen: the store, the clock and repository factories.
///
/// Read it with `@Environment(\.services)`. Repositories are main-actor and work on the
/// container's `mainContext`; build one where it is used instead of storing it.
struct AppServices: Sendable {
    let container: ModelContainer
    let clock: any Clock

    init(container: ModelContainer, clock: any Clock) {
        self.container = container
        self.clock = clock
    }

    /// `FixedClock` when `-today` was given, the device clock otherwise.
    static func makeClock(for launchOptions: LaunchOptions) -> any Clock {
        if let today = launchOptions.today { return FixedClock(day: today) }
        return SystemClock()
    }

    /// The current calendar day by the injected clock.
    var today: DayKey { clock.today }

    @MainActor var context: ModelContext { container.mainContext }

    @MainActor func habitRepository() -> HabitRepository {
        HabitRepository(context: context, clock: clock)
    }

    @MainActor func completionRepository() -> CompletionRepository {
        CompletionRepository(context: context, clock: clock)
    }

    @MainActor func reminderRepository() -> ReminderRepository {
        ReminderRepository(context: context)
    }

    @MainActor func dataTransfer() -> DataTransfer {
        DataTransfer(context: context)
    }
}

private struct ServicesKey: EnvironmentKey {
    /// Empty in-memory store, used by previews and when nothing is injected.
    static let defaultValue: AppServices = {
        do {
            let container = try HabitatStore.makeContainer(StoreConfiguration(inMemory: true))
            return AppServices(container: container, clock: SystemClock())
        } catch {
            fatalError("Cannot create the default in-memory store: \(error)")
        }
    }()
}

extension EnvironmentValues {
    var services: AppServices {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}
