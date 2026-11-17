import XCTest

/// R-DATA (export and about) on the Settings tab. Ids are from docs/status/p7.md.
/// The system share sheet and file picker run out of process; tests check that they appear.
final class SettingsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchSettings(seed: String = "typical") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seed", seed, "-today", "2026-11-03", "-fakeNotifications"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(el(app, "settings.screen").waitForExistence(timeout: 5), "settings.screen")
        return app
    }

    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// The share sheet is an `UIActivityViewController` hosted out of process.
    private func shareSheet(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements["ActivityListView"].firstMatch
    }

    private func dismissShareSheet(_ app: XCUIApplication) {
        let close = app.buttons["Close"].firstMatch
        if close.exists { close.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap() }
    }

    @MainActor
    func testExportShowsShareSheetAndNoError() {
        let app = launchSettings()
        let export = el(app, "settings.export")
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(export.isEnabled)
        export.tap()
        let sheet = shareSheet(app)
        let shown = sheet.waitForExistence(timeout: 10)
            || app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'habitat-export'"))
                .firstMatch.exists
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'habitat-export'")).firstMatch.exists
        XCTAssertTrue(shown, "share sheet did not appear")
        XCTAssertFalse(el(app, "settings.exportError").exists, "no export error")
    }

    @MainActor
    func testExportOfEmptyStoreAlsoWorks() {
        let app = launchSettings(seed: "empty")
        el(app, "settings.export").tap()
        let shown = shareSheet(app).waitForExistence(timeout: 10)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'habitat-export'")).firstMatch.exists
        XCTAssertTrue(shown, "share sheet did not appear for an empty store")
        XCTAssertFalse(el(app, "settings.exportError").exists)
    }

    @MainActor
    func testExportCanBeRepeatedAfterDismissingTheSheet() {
        let app = launchSettings()
        el(app, "settings.export").tap()
        XCTAssertTrue(shareSheet(app).waitForExistence(timeout: 10))
        dismissShareSheet(app)
        XCTAssertTrue(el(app, "settings.export").waitForExistence(timeout: 10), "back on Settings")
        el(app, "settings.export").tap()
        XCTAssertTrue(shareSheet(app).waitForExistence(timeout: 10), "second export shows the sheet again")
        XCTAssertFalse(el(app, "settings.exportError").exists)
    }

    @MainActor
    func testAboutSectionShowsNameVersionAndPrivacyNote() {
        let app = launchSettings()
        let texts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        XCTAssertTrue(app.staticTexts["Habitat"].exists, "app name; texts: \(texts)")
        XCTAssertTrue(app.staticTexts["Data stays on this device."].exists, "texts: \(texts)")
        let version = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*[0-9]+\\\\.[0-9]+.*'")).firstMatch
        XCTAssertTrue(version.exists, "version string; texts: \(texts)")
    }

    @MainActor
    func testNoErrorOrImportResultShownOnLaunch() {
        let app = launchSettings()
        for id in ["settings.exportError", "settings.importError", "settings.importResult"] {
            XCTAssertFalse(el(app, id).exists, id)
        }
        XCTAssertTrue(el(app, "settings.import").exists)
    }

    @MainActor
    func testImportOpensFilePickerAndCancelChangesNothing() {
        let app = launchSettings()
        el(app, "settings.import").tap()
        // The document picker is out of process; it is up when the Settings screen is covered.
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "file picker did not appear")
        cancel.tap()
        XCTAssertTrue(el(app, "settings.import").waitForExistence(timeout: 10), "back on Settings")
        XCTAssertFalse(el(app, "settings.importError").exists)
        XCTAssertFalse(el(app, "settings.importResult").exists)
        XCTAssertFalse(app.buttons["Merge"].exists, "no merge/replace dialog without a file")
    }

    // MARK: R-A11Y

    @MainActor
    func testAuditSettings() throws {
        let app = launchSettings()
        XCTAssertTrue(el(app, "settings.export").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA57-7: settings audit (Contrast nearly passed)", strict: false)
        try app.performAccessibilityAudit()
    }
}
