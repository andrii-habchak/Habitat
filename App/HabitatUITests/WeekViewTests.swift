import XCTest

/// R-WEEK and R-STREAK on the Week tab. Today is pinned to Tuesday 2026-11-03.
/// Ids are from docs/status/p4.md. Cell ids carry the upper-case habit UUID.
final class WeekViewTests: XCTestCase {
    private func hid(_ index: Int) -> String { HabitsListTests.id(index) }

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchWeek(seed: String = "typical") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seed", seed, "-today", "2026-11-03", "-fakeNotifications"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(el(app, "week.previous").waitForExistence(timeout: 5))
        return app
    }

    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func cell(_ app: XCUIApplication, _ habit: Int, _ day: String) -> XCUIElement {
        el(app, "week.cell.\(hid(habit)).\(day)")
    }

    @MainActor
    func testCurrentWeekTitleAndScreenElement() {
        let app = launchWeek()
        XCTAssertTrue(app.navigationBars["2 \u{2013} 8 Nov 2026"].waitForExistence(timeout: 5)
                      || app.staticTexts["2 \u{2013} 8 Nov 2026"].exists)
        XCTAssertTrue(el(app, "week.screen").exists, "week.screen resolves on the paged TabView")
    }

    @MainActor
    func testTodayColumnIsHighlightedInSpokenLabel() {
        let app = launchWeek()
        let today = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Tuesday 3 November, today'")).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 5), "today column header")
        XCTAssertFalse(app.descendants(matching: .any)["Monday 2 November, today"].exists)
    }

    @MainActor
    func testHabitHeadersShowNames() {
        let app = launchWeek()
        let header = el(app, "week.header.\(hid(1)).2026-11-02")
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label, "Read")
    }

    @MainActor
    func testTapCellTogglesDoneAndUpdatesWeeklyProgress() {
        let app = launchWeek()
        // Workout (weekly 3): seeded Mon + Tue done (c = 2), Wed 4 Nov is future.
        let progress = el(app, "week.progress.\(hid(2)).2026-11-02")
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.hasSuffix("2 done"), progress.label)
        XCTAssertEqual(progress.value as? String, "in progress")

        let tue = cell(app, 2, "2026-11-03")
        XCTAssertEqual(tue.value as? String, "done")
        tue.tap()
        XCTAssertEqual(tue.value as? String, "not done")
        XCTAssertTrue(progress.label.hasSuffix("1 done"), progress.label)
        tue.tap()
        XCTAssertEqual(tue.value as? String, "done")
        XCTAssertTrue(progress.label.hasSuffix("2 done"), progress.label)

        // Toggle a past day: Monday not done -> done is allowed; c goes to 3 would need it not done.
        let mon = cell(app, 2, "2026-11-02")
        XCTAssertEqual(mon.value as? String, "done")
        mon.tap()
        XCTAssertEqual(mon.value as? String, "not done")
        XCTAssertTrue(progress.label.hasSuffix("1 done"), progress.label)
    }

    @MainActor
    func testFutureDaysAreDisabledAndPastAndTodayEnabled() {
        let app = launchWeek()
        for day in ["2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"] {
            let future = cell(app, 1, day)
            XCTAssertTrue(future.waitForExistence(timeout: 5), day)
            XCTAssertFalse(future.isEnabled, "\(day) must be disabled")
        }
        XCTAssertTrue(cell(app, 1, "2026-11-02").isEnabled)
        XCTAssertTrue(cell(app, 1, "2026-11-03").isEnabled)
    }

    @MainActor
    func testFutureCellTapDoesNotChangeValue() {
        let app = launchWeek()
        let wed = cell(app, 1, "2026-11-04")
        XCTAssertEqual(wed.value as? String, "not done")
        wed.tap()
        XCTAssertEqual(wed.value as? String, "not done")
    }

    @MainActor
    func testPreviousWeekViaChevronShowsDifferentWeekWithUniqueIds() {
        let app = launchWeek()
        XCTAssertTrue(el(app, "week.progress.\(hid(2)).2026-11-02").waitForExistence(timeout: 5))
        el(app, "week.previous").tap()
        XCTAssertTrue(app.navigationBars["26 Oct \u{2013} 1 Nov 2026"].waitForExistence(timeout: 5)
                      || app.staticTexts["26 Oct \u{2013} 1 Nov 2026"].exists, "previous week title")
        let prev = el(app, "week.progress.\(hid(2)).2026-10-26")
        XCTAssertTrue(prev.waitForExistence(timeout: 5), "previous week progress id")
        XCTAssertEqual(prev.value as? String, "met")
        // Past days are enabled; the previous week has no future days.
        XCTAssertTrue(cell(app, 1, "2026-11-01").isEnabled)
        el(app, "week.next").tap()
        XCTAssertTrue(el(app, "week.progress.\(hid(2)).2026-11-02").waitForExistence(timeout: 5))
    }

    @MainActor
    func testSwipeToPreviousWeek() {
        let app = launchWeek()
        XCTAssertTrue(el(app, "week.progress.\(hid(2)).2026-11-02").waitForExistence(timeout: 5))
        let screen = app.windows.firstMatch
        screen.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: screen.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(el(app, "week.progress.\(hid(2)).2026-10-26").waitForExistence(timeout: 5),
                      "swiping right shows the previous week")
    }

    @MainActor
    func testWeeklyStatusFailedMetInProgress() {
        let app = launchWeek()
        // Current week: Workout in progress (c 2 of 3, days left), Call family met (c 2 of 1).
        XCTAssertEqual(el(app, "week.progress.\(hid(2)).2026-11-02").value as? String, "in progress")
        XCTAssertEqual(el(app, "week.progress.\(hid(5)).2026-11-02").value as? String, "met")
        // Two weeks back nothing was done (habits created 6 Oct): Workout failed.
        el(app, "week.previous").tap()
        el(app, "week.previous").tap()
        let failed = el(app, "week.progress.\(hid(2)).2026-10-19")
        XCTAssertTrue(failed.waitForExistence(timeout: 5))
        XCTAssertEqual(failed.value as? String, "failed")
    }

    @MainActor
    func testDailyHabitsHaveNoWeeklyProgress() {
        let app = launchWeek()
        XCTAssertTrue(el(app, "week.header.\(hid(1)).2026-11-02").waitForExistence(timeout: 5))
        XCTAssertFalse(el(app, "week.progress.\(hid(1)).2026-11-02").exists)
    }

    @MainActor
    func testStreakValuesWithStreaksSeed() {
        let app = launchWeek(seed: "streaks")
        XCTAssertEqual(el(app, "week.streak.\(hid(1)).2026-11-02").value as? String, "10")
        XCTAssertEqual(el(app, "week.streak.\(hid(2)).2026-11-02").value as? String, "3")
        XCTAssertEqual(el(app, "week.streak.\(hid(3)).2026-11-02").value as? String, "4")
        let three = cell(app, 2, "2026-11-03")
        three.tap()
        XCTAssertEqual(el(app, "week.streak.\(hid(2)).2026-11-02").value as? String, "4")
    }

    @MainActor
    func testEmptySeedShowsEmptyWeekState() {
        let app = launchWeek(seed: "empty")
        XCTAssertTrue(el(app, "week.emptyState.2026-11-02").waitForExistence(timeout: 5))
    }

    @MainActor
    func testAuditWeekWithData() throws {
        let app = launchWeek()
        XCTAssertTrue(el(app, "week.progress.\(hid(2)).2026-11-02").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA34-3: week fails audit (Hit area is too small)", strict: false)
        try app.performAccessibilityAudit()
    }
}
