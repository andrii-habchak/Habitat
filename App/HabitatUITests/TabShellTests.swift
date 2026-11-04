import XCTest

/// Tab shell acceptance tests (PLAN §3, §4 R-A11Y, §6 step 4).
/// Identifiers follow `docs/accessibility-ids.md`; tab buttons are found by label.
final class TabShellTests: XCTestCase {
    private let tabs: [(label: String, screen: String)] = [
        ("Habits", "habits"),
        ("Week", "week"),
        ("Month", "month"),
        ("Reminders", "reminders"),
        ("Settings", "settings")
    ]
    private let baseArguments = ["-uiTesting", "-today", "2026-11-03", "-fakeNotifications"]

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + extra
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar did not appear")
        return app
    }

    private func placeholder(_ app: XCUIApplication, _ screen: String) -> XCUIElement {
        // Habits and Week are built (`<tab>.screen`); the others still show a placeholder.
        let built: Set<String> = ["habits", "week"]
        let suffix = built.contains(screen) ? "screen" : "placeholder"
        return app.descendants(matching: .any)["\(screen).\(suffix)"]
    }

    @MainActor
    func testTabsAreFiveInDocumentedOrder() {
        let app = launch()
        let buttons = app.tabBars.firstMatch.buttons
        XCTAssertEqual(buttons.count, 5)
        for (index, tab) in tabs.enumerated() {
            XCTAssertEqual(buttons.element(boundBy: index).label, tab.label, "tab \(index) label")
        }
    }

    @MainActor
    func testHabitsIsTheFirstScreenAndOnlyItsPlaceholderShows() {
        let app = launch()
        XCTAssertTrue(placeholder(app, "habits").waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Habits"].isSelected)
        XCTAssertFalse(placeholder(app, "week").exists)
    }

    @MainActor
    func testEachTabShowsOnlyItsOwnPlaceholder() {
        let app = launch()
        for tab in tabs {
            app.tabBars.buttons[tab.label].tap()
            XCTAssertTrue(placeholder(app, tab.screen).waitForExistence(timeout: 5), "\(tab.label) placeholder")
            XCTAssertTrue(app.tabBars.buttons[tab.label].isSelected, "\(tab.label) selected")
            for other in tabs where other.screen != tab.screen {
                XCTAssertFalse(placeholder(app, other.screen).exists, "\(other.label) leaked into \(tab.label)")
            }
        }
    }

    @MainActor
    func testSwitchingBackAndForthInReverseOrder() {
        let app = launch()
        for tab in tabs.reversed() {
            app.tabBars.buttons[tab.label].tap()
            XCTAssertTrue(placeholder(app, tab.screen).waitForExistence(timeout: 5), "\(tab.label) placeholder")
        }
        app.tabBars.buttons["Habits"].tap()
        XCTAssertTrue(placeholder(app, "habits").waitForExistence(timeout: 5))
    }

    @MainActor
    func testRelaunchStartsOnHabitsAgain() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(placeholder(app, "settings").waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(placeholder(app, "habits").waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.firstMatch.buttons.count, 5)
    }

    @MainActor
    func testLaunchWithSeedFixtureDoesNotCrash() {
        // Known fixture; an unknown name currently crashes the app (see docs/status/qa-p3p4.md).
        let app = launch(extra: ["-seed", "typical"])
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(placeholder(app, "habits").waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchWithMalformedTodayDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-today", "2026-02-30", "-fakeNotifications"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(placeholder(app, "habits").waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargeDynamicTypeKeepsAllTabsReachable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for tab in tabs {
            let button = app.tabBars.buttons[tab.label]
            XCTAssertTrue(button.exists, "\(tab.label) tab missing at large type")
            button.tap()
            XCTAssertTrue(placeholder(app, tab.screen).waitForExistence(timeout: 5), "\(tab.label) at large type")
        }
    }

    /// R-A11Y: `performAccessibilityAudit()` on each main screen, one test per tab so a failure
    /// names the tab.
    private func audit(_ label: String, screen: String, knownContrastIssue: Bool = false) throws {
        let app = launch()
        app.tabBars.buttons[label].tap()
        XCTAssertTrue(placeholder(app, screen).waitForExistence(timeout: 5))
        if knownContrastIssue {
            // BUG-QA34-4: the Habits empty state ("No habits yet") reports "Contrast nearly passed".
            XCTExpectFailure("BUG-QA34-4 Habits empty state contrast", strict: false)
        }
        try app.performAccessibilityAudit()
    }

    @MainActor func testAuditHabits() throws { try audit("Habits", screen: "habits", knownContrastIssue: true) }
    @MainActor func testAuditWeek() throws { try audit("Week", screen: "week") }
    @MainActor func testAuditMonth() throws { try audit("Month", screen: "month") }
    @MainActor func testAuditReminders() throws { try audit("Reminders", screen: "reminders") }
    @MainActor func testAuditSettings() throws { try audit("Settings", screen: "settings") }
}
