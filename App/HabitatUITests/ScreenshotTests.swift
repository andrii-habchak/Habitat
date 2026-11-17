import XCTest

/// Visual pass (PLAN §7): one PNG per tab in light, dark and Dynamic Type XXXL, written to
/// `docs/status/screenshots/qa-p5p7/`. Skipped unless run with `TEST_RUNNER_HABITAT_SHOTS=1`.
final class ScreenshotTests: XCTestCase {
    private let tabs = ["Habits", "Week", "Month", "Reminders", "Settings"]
    private let variants: [(name: String, args: [String])] = [
        ("light", ["-AppleInterfaceStyle", "Light"]),
        ("dark", ["-AppleInterfaceStyle", "Dark"]),
        ("xxxl", ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    private var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/status/screenshots/qa-p5p7")
    }

    @MainActor
    func testCaptureAllTabs() throws {
        let enabled = ProcessInfo.processInfo.environment["HABITAT_SHOTS"] == "1"
        try XCTSkipUnless(enabled, "set TEST_RUNNER_HABITAT_SHOTS=1")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        // `HABITAT_SHOTS_VARIANT` limits the run to one variant; dark needs the simulator switched first
        // (`xcrun simctl ui <udid> appearance dark`), the launch argument alone does not change the scheme.
        let only = ProcessInfo.processInfo.environment["HABITAT_SHOTS_VARIANT"]
        for variant in variants where only == nil || only == variant.name {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-seed", "typical", "-today", "2026-11-03", "-fakeNotifications"]
                + variant.args
            app.launch()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
            for tab in tabs {
                app.tabBars.buttons[tab].tap()
                sleep(1)
                let data = XCUIScreen.main.screenshot().pngRepresentation
                let file = outputDirectory.appendingPathComponent("\(tab.lowercased())-\(variant.name).png")
                try data.write(to: file)
            }
            app.terminate()
        }
    }
}
