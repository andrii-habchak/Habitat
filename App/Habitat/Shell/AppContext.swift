import HabitatCore
import HabitatData
import SwiftUI

/// Launch-time configuration shared with every screen.
struct AppContext: Equatable, Sendable {
    let launchOptions: LaunchOptions
    let storeConfiguration: StoreConfiguration

    init(launchOptions: LaunchOptions) {
        self.launchOptions = launchOptions
        self.storeConfiguration = StoreConfiguration(launchOptions: launchOptions)
    }

    static let standard = AppContext(launchOptions: .standard)
}

private struct AppContextKey: EnvironmentKey {
    static let defaultValue = AppContext.standard
}

extension EnvironmentValues {
    var appContext: AppContext {
        get { self[AppContextKey.self] }
        set { self[AppContextKey.self] = newValue }
    }
}
