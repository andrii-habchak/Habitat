import HabitatCore
import SwiftUI

@main
struct HabitatApp: App {
    private let context = AppContext(launchOptions: LaunchOptions(arguments: ProcessInfo.processInfo.arguments))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContext, context)
        }
    }
}
