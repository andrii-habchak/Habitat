import HabitatCore
import Testing

@Suite("LaunchOptions")
struct LaunchOptionsTests {
    @Test("No arguments gives the standard options")
    func empty() {
        #expect(LaunchOptions(arguments: []) == .standard)
        #expect(LaunchOptions(arguments: ["/path/to/Habitat"]) == .standard)
    }

    @Test("All test hooks are parsed together")
    func allFlags() {
        let options = LaunchOptions(arguments: [
            "/path/to/Habitat", "-uiTesting", "-seed", "twoHabits",
            "-today", "2026-11-03", "-fakeNotifications"
        ])
        #expect(options == LaunchOptions(
            uiTesting: true, seed: "twoHabits", today: "2026-11-03", fakeNotifications: true
        ))
    }

    @Test("Unknown arguments, including Xcode's own, are ignored")
    func unknownArguments() {
        let options = LaunchOptions(arguments: [
            "-NSDocumentRevisionsDebugMode", "YES", "-AppleLanguages", "(en)", "-uiTesting"
        ])
        #expect(options == LaunchOptions(uiTesting: true))
    }

    @Test("A flag without its value is dropped and does not swallow the next flag")
    func missingValues() {
        let options = LaunchOptions(arguments: ["-seed", "-uiTesting", "-today"])
        #expect(options == LaunchOptions(uiTesting: true))
    }

    @Test("Malformed or impossible days are rejected", arguments: [
        "2026-02-30", "2025-02-29", "2100-02-29", "1900-02-29", "2026-13-01", "2026-00-10", "2026-04-31",
        "26-11-03", "2026-1-03", "2026/11/03", "2026-11-03T00:00", "abcd-ef-gh", ""
    ])
    func invalidToday(_ value: String) {
        #expect(LaunchOptions(arguments: ["-today", value]).today == nil)
    }

    @Test("Real days are accepted, including leap days", arguments: [
        "2026-11-03", "2024-02-29", "2000-02-29", "2026-12-31", "2026-01-01"
    ])
    func validToday(_ value: String) {
        #expect(LaunchOptions(arguments: ["-today", value]).today == value)
    }

    @Test("A later malformed -today does not reset an earlier valid one")
    func malformedRepeatKeepsValidDay() {
        let options = LaunchOptions(arguments: ["-today", "2026-11-03", "-today", "2026-02-30"])
        #expect(options.today == "2026-11-03")
    }

    @Test("The last occurrence of a repeated option wins")
    func repeated() {
        let options = LaunchOptions(arguments: ["-seed", "a", "-seed", "b"])
        #expect(options.seed == "b")
    }
}
