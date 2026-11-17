import HabitatCore
import HabitatData
import OSLog
import SwiftData
import SwiftUI

@main
struct HabitatApp: App {
    private let context: AppContext
    private let services: AppServices
    private let reminderSync: ReminderSync
    /// Kept here because the notification centre holds its delegate weakly.
    private let notificationDelegate: ReminderNotificationDelegate

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let context = AppContext(launchOptions: LaunchOptions(arguments: ProcessInfo.processInfo.arguments))
        let clock = AppServices.makeClock(for: context.launchOptions)
        do {
            let container = try MainActor.assumeIsolated {
                try Self.prepareStore(context.storeConfiguration, clock: clock)
            }
            self.services = AppServices(container: container, clock: clock)
        } catch {
            fatalError("Habitat could not open its data store: \(error)")
        }
        self.context = context
        let services = self.services
        (reminderSync, notificationDelegate) = MainActor.assumeIsolated {
            let scheduler = ReminderSync.makeScheduler(for: context.launchOptions)
            let sync = ReminderSync(services: services, scheduler: scheduler)
            let delegate = ReminderNotificationDelegate(sync: sync)
            delegate.install()
            return (sync, delegate)
        }
    }

    /// An unknown `-seed` name is logged and ignored (the store starts empty) instead of crashing.
    @MainActor
    private static func prepareStore(_ configuration: StoreConfiguration, clock: any Clock) throws -> ModelContainer {
        do {
            return try HabitatStore.prepare(configuration, clock: clock)
        } catch let error as SeedError {
            Logger(subsystem: "io.github.andrii-habchak.Habitat", category: "launch")
                .error("Ignoring seed: \(error.description, privacy: .public)")
            var unseeded = configuration
            unseeded.seedFixture = nil
            return try HabitatStore.prepare(unseeded, clock: clock)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContext, context)
                .environment(\.services, services)
                .environment(\.reminderSync, reminderSync)
                .modelContainer(services.container)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { reminderSync.sceneDidBecomeActive() }
        }
    }
}
