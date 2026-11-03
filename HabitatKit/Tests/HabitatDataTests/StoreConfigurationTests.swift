import HabitatCore
import HabitatData
import Testing

@Suite("StoreConfiguration")
struct StoreConfigurationTests {
    @Test("A normal launch uses the on-disk store without a seed")
    func standardLaunch() {
        #expect(StoreConfiguration(launchOptions: .standard) == StoreConfiguration())
    }

    @Test("-uiTesting selects the in-memory store and keeps the seed")
    func uiTestingLaunch() {
        let options = LaunchOptions(arguments: ["-uiTesting", "-seed", "twoHabits"])
        let configuration = StoreConfiguration(launchOptions: options)
        #expect(configuration.inMemory)
        #expect(configuration.seedFixture == "twoHabits")
    }
}
