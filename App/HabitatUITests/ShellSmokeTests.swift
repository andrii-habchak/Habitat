import XCTest

/// Smoke test: the app launches into the tab shell and every tab shows its screen.
/// Identifiers follow `docs/accessibility-ids.md`.
final class ShellSmokeTests: XCTestCase {
    private let tabs: [(label: String, screen: String)] = [
        ("Habits", "habits"),
        ("Week", "week"),
        ("Month", "month"),
        ("Reminders", "reminders"),
        ("Settings", "settings")
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTabShellLaunchesAndEachTabOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-today", "2026-11-03", "-fakeNotifications"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar did not appear")
        XCTAssertEqual(tabBar.buttons.count, tabs.count)

        for tab in tabs {
            let button = tabBar.buttons[tab.label]
            XCTAssertTrue(button.exists, "missing tab \(tab.label)")
            button.tap()
            let placeholder = app.descendants(matching: .any)["\(tab.screen).placeholder"]
            XCTAssertTrue(placeholder.waitForExistence(timeout: 5), "\(tab.label) screen did not show")
        }
    }
}
