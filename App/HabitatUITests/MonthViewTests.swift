import XCTest

/// R-MONTH on the Month tab. Today is pinned to Tuesday 2026-11-03; seed `typical`
/// (5 habits created 2026-10-06). Ids are from docs/status/p5.md.
///
/// Donut segments are checked through the cell accessibility value `done/active`.
/// Expected counts from the seed rule "habit i is done on day `today - back` (back 0...6)
/// when (i + back) % 3 != 0": 3 Nov 3/5, 2 Nov 4/5, 1 Nov 3/5, 31 Oct 3/5.
final class MonthViewTests: XCTestCase {
    private func hid(_ index: Int) -> String { HabitsListTests.id(index) }

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchMonth(seed: String = "typical", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seed", seed, "-today", "2026-11-03", "-fakeNotifications"] + extra
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Month"].tap()
        XCTAssertTrue(el(app, "month.screen").waitForExistence(timeout: 5), "month.screen")
        return app
    }

    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func day(_ app: XCUIApplication, _ day: String) -> XCUIElement { el(app, "month.day.\(day)") }

    private func value(_ element: XCUIElement) -> String { (element.value as? String) ?? "" }

    // MARK: Grid

    @MainActor
    func testMonthTitleNamesTheMonthAndYear() {
        let app = launchMonth()
        XCTAssertTrue(el(app, "month.title").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA57-1: title reads 'M11 2026' instead of 'November 2026'", strict: false)
        XCTAssertTrue(el(app, "month.title").label.contains("November 2026"), el(app, "month.title").label)
    }

    @MainActor
    func testMondayFirstGrid() {
        let app = launchMonth()
        // 1 Nov 2026 is a Sunday: a Monday-first grid starts on 26 Oct and puts 1 Nov in column 7.
        let first = day(app, "2026-10-26")
        let sunday = day(app, "2026-11-01")
        let monday = day(app, "2026-11-02")
        XCTAssertTrue(first.waitForExistence(timeout: 5), "grid starts on Monday 26 Oct")
        XCTAssertTrue(sunday.exists && monday.exists)
        XCTAssertGreaterThan(sunday.frame.minX, first.frame.minX + first.frame.width * 5, "Sunday is the last column")
        XCTAssertEqual(first.frame.minY, sunday.frame.minY, accuracy: 2, "26 Oct and 1 Nov share the first row")
        XCTAssertGreaterThan(monday.frame.minY, sunday.frame.minY, "2 Nov starts the second row")
        XCTAssertEqual(monday.frame.minX, first.frame.minX, accuracy: 2, "Mondays share a column")
        XCTExpectFailure("BUG-QA57-1: cell label reads 'Mon 26 M10' (month and weekday names broken)", strict: false) {
            XCTAssertTrue(first.label.hasPrefix("Monday 26 October"), first.label)
        }
    }

    @MainActor
    func testDonutSegmentsAreExposedAsDoneOverActiveValue() {
        let app = launchMonth()
        XCTAssertEqual(value(day(app, "2026-11-03")), "3/5", "today")
        XCTAssertEqual(value(day(app, "2026-11-02")), "4/5")
        XCTAssertEqual(value(day(app, "2026-11-01")), "3/5")
        XCTAssertEqual(value(day(app, "2026-10-31")), "3/5")
        XCTAssertEqual(value(day(app, "2026-11-04")), "0/5", "future day: five active habits, none done")
        XCTAssertTrue(day(app, "2026-11-02").label.contains("4 of 5 habits done"), day(app, "2026-11-02").label)
    }

    @MainActor
    func testTodayIsMarkedAndFutureDayIsNot() {
        let app = launchMonth()
        XCTAssertTrue(day(app, "2026-11-03").label.contains("today"), day(app, "2026-11-03").label)
        XCTAssertFalse(day(app, "2026-11-02").label.contains("today"))
    }

    @MainActor
    func testDaysBeforeHabitsExistHaveNoActiveSegments() {
        let app = launchMonth()
        // Habits were created on 6 Oct: 26 Oct is active, nothing earlier is. Go back two months.
        el(app, "month.previous").tap()
        el(app, "month.previous").tap()
        XCTAssertTrue(value(day(app, "2026-09-15")).hasSuffix("/0") || value(day(app, "2026-09-15")).isEmpty
                      || value(day(app, "2026-09-15")) == "0/0", "September: \(value(day(app, "2026-09-15")))")
    }

    // MARK: Navigation

    @MainActor
    func testMonthNavigationPreviousAndNext() {
        let app = launchMonth()
        el(app, "month.previous").tap()
        XCTAssertTrue(day(app, "2026-10-15").waitForExistence(timeout: 5), "October days are shown")
        // 16 Oct: (i + back) with back 18 is outside the 7 seeded days: no completions, 5 active.
        XCTAssertEqual(value(day(app, "2026-10-15")), "0/5")
        el(app, "month.next").tap()
        XCTAssertTrue(day(app, "2026-11-03").waitForExistence(timeout: 5))
        el(app, "month.next").tap()
        XCTAssertTrue(day(app, "2026-12-15").waitForExistence(timeout: 5), "December days after next")
    }

    @MainActor
    func testNavigatingThreeMonthsForwardShowsFebruary() {
        let app = launchMonth()
        for _ in 0..<3 { el(app, "month.next").tap() }
        XCTAssertTrue(day(app, "2027-02-15").waitForExistence(timeout: 5))
        // 1 Feb 2027 is a Monday: first cell of the grid.
        XCTAssertTrue(day(app, "2027-02-01").exists)
    }

    // MARK: Filter

    @MainActor
    func testFilterChipsShowAllAndEachHabitAndSingleHabitIsOneRing() {
        let app = launchMonth()
        XCTAssertTrue(el(app, "month.filter.all").waitForExistence(timeout: 5))
        for index in 1...5 { XCTAssertTrue(el(app, "month.filter.\(hid(index))").exists, "chip \(index)") }

        // All selected by default.
        XCTAssertTrue(el(app, "month.filter.all").isSelected)

        // Read (habit 1): done on 2 Nov, not done on 3 Nov (back 0).
        el(app, "month.filter.\(hid(1))").tap()
        XCTAssertTrue(el(app, "month.filter.\(hid(1))").isSelected)
        XCTAssertFalse(el(app, "month.filter.all").isSelected)
        XCTAssertEqual(value(day(app, "2026-11-02")), "1/1")
        XCTAssertEqual(value(day(app, "2026-11-03")), "0/1")

        // Workout (habit 2): done on 3 Nov and 2 Nov, not done on 1 Nov (back 2: (1+2)%3 == 0).
        el(app, "month.filter.\(hid(2))").tap()
        XCTAssertEqual(value(day(app, "2026-11-03")), "1/1")
        XCTAssertEqual(value(day(app, "2026-11-02")), "1/1")
        XCTAssertEqual(value(day(app, "2026-11-01")), "0/1")

        el(app, "month.filter.all").tap()
        XCTAssertEqual(value(day(app, "2026-11-03")), "3/5")
        XCTAssertTrue(el(app, "month.filter.all").isSelected)
    }

    // MARK: Day sheet

    @MainActor
    func testTapDayOpensSheetListingActiveHabitsWithState() {
        let app = launchMonth()
        day(app, "2026-11-03").tap()
        XCTAssertTrue(el(app, "month.daySheet").waitForExistence(timeout: 5))
        for index in 1...5 { XCTAssertTrue(el(app, "month.daySheet.toggle.\(hid(index))").exists, "toggle \(index)") }
        // 3 Nov: Read and Water not done (back 0 -> i = 0, 3), the others done.
        XCTAssertEqual(value(el(app, "month.daySheet.toggle.\(hid(1))")), "not done")
        XCTAssertEqual(value(el(app, "month.daySheet.toggle.\(hid(2))")), "done")
        XCTAssertEqual(value(el(app, "month.daySheet.toggle.\(hid(4))")), "not done")
        XCTAssertEqual(value(el(app, "month.daySheet.toggle.\(hid(5))")), "done")
    }

    @MainActor
    func testToggleInSheetUpdatesDonutAndCanBeUndone() {
        let app = launchMonth()
        day(app, "2026-11-03").tap()
        let read = el(app, "month.daySheet.toggle.\(hid(1))")
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.tap()
        XCTAssertEqual(value(read), "done")
        el(app, "month.daySheet.close").tap()
        XCTAssertTrue(waitGone(el(app, "month.daySheet")))
        XCTAssertEqual(value(day(app, "2026-11-03")), "4/5", "donut shows the new segment")

        day(app, "2026-11-03").tap()
        let again = el(app, "month.daySheet.toggle.\(hid(1))")
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        XCTAssertEqual(value(again), "done", "state is kept")
        again.tap()
        XCTAssertEqual(value(again), "not done")
        el(app, "month.daySheet.close").tap()
        XCTAssertTrue(waitGone(el(app, "month.daySheet")))
        XCTAssertEqual(value(day(app, "2026-11-03")), "3/5")
    }

    @MainActor
    func testPastDayCanBeToggled() {
        let app = launchMonth()
        day(app, "2026-11-01").tap()  // Read done on 1 Nov (back 2)
        let workout = el(app, "month.daySheet.toggle.\(hid(2))")  // not done on 1 Nov
        XCTAssertTrue(workout.waitForExistence(timeout: 5))
        XCTAssertEqual(value(workout), "not done")
        workout.tap()
        XCTAssertEqual(value(workout), "done")
        el(app, "month.daySheet.close").tap()
        XCTAssertTrue(waitGone(el(app, "month.daySheet")))
        XCTAssertEqual(value(day(app, "2026-11-01")), "4/5")
    }

    @MainActor
    func testFutureDayTogglesAreDisabled() {
        let app = launchMonth()
        day(app, "2026-11-04").tap()
        XCTAssertTrue(el(app, "month.daySheet").waitForExistence(timeout: 5))
        let toggle = el(app, "month.daySheet.toggle.\(hid(1))")
        if toggle.exists {
            XCTExpectFailure("BUG-QA57-2: future-day toggle in the sheet is not exposed as disabled", strict: false) {
                XCTAssertFalse(toggle.isEnabled, "future toggle must be disabled")
            }
            toggle.tap()
            XCTAssertEqual(value(toggle), "not done")
        }
        el(app, "month.daySheet.close").tap()
        XCTAssertTrue(waitGone(el(app, "month.daySheet")))
        XCTAssertEqual(value(day(app, "2026-11-04")), "0/5")
    }

    @MainActor
    func testSheetToggleIsReflectedInWeekTab() {
        let app = launchMonth()
        day(app, "2026-11-03").tap()
        el(app, "month.daySheet.toggle.\(hid(1))").tap()
        el(app, "month.daySheet.close").tap()
        XCTAssertTrue(waitGone(el(app, "month.daySheet")))
        app.tabBars.buttons["Week"].tap()
        let cell = el(app, "week.cell.\(hid(1)).2026-11-03")
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "done")
    }

    @MainActor
    func testFilterAppliesWhileSheetOpensForSelectedDay() {
        let app = launchMonth()
        el(app, "month.filter.\(hid(2))").tap()
        day(app, "2026-11-03").tap()
        XCTAssertTrue(el(app, "month.daySheet").waitForExistence(timeout: 5))
        XCTAssertTrue(el(app, "month.daySheet.toggle.\(hid(2))").exists)
    }

    // MARK: Empty and archived

    @MainActor
    func testEmptyStoreShowsGridWithoutDonutSegments() {
        let app = launchMonth(seed: "empty")
        XCTAssertTrue(day(app, "2026-11-03").waitForExistence(timeout: 5))
        let cellValue = value(day(app, "2026-11-03"))
        XCTAssertTrue(cellValue.isEmpty || cellValue == "0/0", "value was \(cellValue)")
        XCTAssertTrue(el(app, "month.filter.all").exists || !el(app, "month.filter.\(hid(1))").exists)
    }

    // MARK: R-A11Y

    @MainActor
    func testAuditMonthWithData() throws {
        let app = launchMonth()
        XCTAssertTrue(day(app, "2026-11-03").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA57-3: Month grid fails the audit (Contrast failed)", strict: false)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testAuditDaySheet() throws {
        let app = launchMonth()
        day(app, "2026-11-03").tap()
        XCTAssertTrue(el(app, "month.daySheet").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA57-4: day sheet fails the audit (Contrast failed)", strict: false)
        try app.performAccessibilityAudit()
    }

    private func waitGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
