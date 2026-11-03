import HabitatCore
import HabitatData
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
                try HabitatStore.prepare(context.storeConfiguration, clock: clock)
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
