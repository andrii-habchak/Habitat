@testable import HabitatCore
import Testing

@Test("Export schema version is 1 (PLAN §2)")
func exportSchemaVersion() {
    #expect(HabitatCore.exportSchemaVersion == 1)
}
