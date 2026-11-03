import HabitatCore

/// How the SwiftData store is set up. The models and the container arrive in P2;
/// this type fixes how launch options map onto storage.
public struct StoreConfiguration: Equatable, Sendable {
    /// Keep everything in memory (UI tests, previews).
    public var inMemory: Bool
    /// Seed fixture to load into an empty store, if any.
    public var seedFixture: String?

    public init(inMemory: Bool = false, seedFixture: String? = nil) {
        self.inMemory = inMemory
        self.seedFixture = seedFixture
    }

    /// `-uiTesting` selects the in-memory store; `-seed` is passed through.
    public init(launchOptions: LaunchOptions) {
        self.init(inMemory: launchOptions.uiTesting, seedFixture: launchOptions.seed)
    }
}
