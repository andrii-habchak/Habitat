import Foundation
import HabitatCore
import SwiftData

/// Builds the SwiftData container from a `StoreConfiguration`.
public enum HabitatStore {
    public static let modelTypes: [any PersistentModel.Type] = [
        HabitModel.self, CompletionModel.self, ReminderModel.self
    ]

    /// In memory for `-uiTesting` (and tests), on disk otherwise. Does not seed.
    public static func makeContainer(_ configuration: StoreConfiguration) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: configuration.inMemory)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    /// Makes the container and, when `configuration.seedFixture` is set and the store is
    /// empty, loads that fixture relative to the clock's today. An unknown fixture name
    /// throws `SeedError.unknownFixture`.
    @MainActor
    public static func prepare(_ configuration: StoreConfiguration, clock: any Clock) throws -> ModelContainer {
        let container = try makeContainer(configuration)
        if let name = configuration.seedFixture {
            try SeedFixture.load(named: name, into: container.mainContext, today: clock.today)
        }
        return container
    }
}
