import HabitatCore
import HabitatData
import SwiftData
import SwiftUI

@main
struct HabitatApp: App {
    private let context: AppContext
    private let services: AppServices

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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContext, context)
                .environment(\.services, services)
                .modelContainer(services.container)
        }
    }
}
