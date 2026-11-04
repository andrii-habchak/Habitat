import XCTest

/// R-LIST and R-STREAK on the Habits tab. Seeds are `typical`, `streaks`, `empty`
/// (HabitatData/SeedFixtures.swift); ids are from docs/status/p3.md.
final class HabitsListTests: XCTestCase {
    static func id(_ index: Int) -> String { "00000000-0000-0000-0001-" + String(format: "%012d", index) }

    override func setUp() {
        continueAfterFailure = false
    }

    func launch(seed: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seed", seed, "-today", "2026-11-03", "-fakeNotifications"] + extra
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["habits.screen"].waitForExistence(timeout: 10))
        return app
    }

    func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func row(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        el(app, "habits.row.\(Self.id(index))")
    }

    // MARK: R-LIST

    @MainActor
    func testTypicalListShowsSeededHabitsWithGoalAndStreak() {
        let app = launch(seed: "typical")
        let expected: [Int: String] = [
            1: "Read, Every day, ", 2: "Workout, 3 times a week, ", 3: "Meditate, Every day, ",
            4: "Water, Every day, ", 5: "Call family, Once a week, "
        ]
        for (index, prefix) in expected {
            let habitRow = row(app, index)
            XCTAssertTrue(habitRow.waitForExistence(timeout: 5), "row \(prefix)")
            XCTAssertTrue(habitRow.label.hasPrefix(prefix), "label was \(habitRow.label)")
            XCTAssertTrue(habitRow.label.contains("streak"), "label has streak: \(habitRow.label)")
        }
    }

    @MainActor
    func testEmptySeedShowsEmptyStateAndAddOpensEditor() {
        let app = launch(seed: "empty")
        XCTAssertTrue(el(app, "habits.empty").waitForExistence(timeout: 5))
        app.buttons["Add habit"].firstMatch.tap()
        XCTAssertTrue(el(app, "habits.editor").waitForExistence(timeout: 5))
        el(app, "habits.editor.cancel").tap()
        XCTAssertTrue(el(app, "habits.empty").waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddHabitWithNameColourAndWeeklyGoal() {
        let app = launch(seed: "empty")
        app.buttons["Add habit"].firstMatch.tap()
        let name = app.textFields["habits.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Stretch ")  // trailing space commits the word before autocorrect can rewrite it
        app.buttons["Red"].tap()  // swatch ids carry the hex; the label is stable
        // Goal: "Times a week", then step the count up once (default 3 -> 4).
        app.segmentedControls["habits.editor.goalKind"].buttons["Times a week"].tap()
        let stepper = el(app, "habits.editor.weeklyCount")
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        el(app, "habits.editor.weeklyCount-Increment").tap()
        el(app, "habits.editor.save").tap()
        let created = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stretch, '")).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 5),
                      "new habit row; rows: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(created.label.hasPrefix("Stretch, 4 times a week"), "weekly goal 4, got: \(created.label)")
    }

    @MainActor
    func testEmptyNameShowsValidationAndDoesNotSave() {
        let app = launch(seed: "empty")
        app.buttons["Add habit"].firstMatch.tap()
        XCTAssertTrue(el(app, "habits.editor").waitForExistence(timeout: 5))
        el(app, "habits.editor.save").tap()
        XCTAssertTrue(el(app, "habits.editor.error").waitForExistence(timeout: 5), "inline message")
        XCTAssertTrue(el(app, "habits.editor").exists, "sheet stays open")
        // Whitespace only is also blank.
        let name = app.textFields["habits.editor.name"]
        name.tap()
        name.typeText("   ")
        el(app, "habits.editor.save").tap()
        XCTAssertTrue(el(app, "habits.editor").exists, "blank name does not save")
    }

    @MainActor
    func testEditRenamesHabit() {
        let app = launch(seed: "typical")
        row(app, 1).tap()
        let name = app.textFields["habits.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Read")
        name.tap()
        name.clearAndType("Read books")
        el(app, "habits.editor.save").tap()
        XCTAssertTrue(row(app, 1).waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, 1).label.hasPrefix("Read books, Every day"), row(app, 1).label)
    }

    @MainActor
    func testArchiveCancelKeepsHabit() {
        let app = launch(seed: "typical")
        row(app, 4).swipeLeft()
        el(app, "habits.archive.\(Self.id(4))").tap()
        let confirm = el(app, "habits.archiveConfirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        // The dialog is a popover without a Cancel button on this OS: tap outside to dismiss.
        let dismiss = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(waitGone(dismiss), "dialog dismissed")
        XCTAssertTrue(row(app, 4).waitForExistence(timeout: 5))
    }

    @MainActor
    func testArchiveHidesHabitAndUnarchiveBringsItBack() {
        let app = launch(seed: "typical")
        row(app, 4).swipeLeft()
        el(app, "habits.archive.\(Self.id(4))").tap()
        let confirm = el(app, "habits.archiveConfirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(waitGone(row(app, 4)), "archived habit leaves the list")
        XCTAssertTrue(row(app, 1).exists, "others stay")

        toggleShowArchived(app)
        XCTAssertTrue(row(app, 4).waitForExistence(timeout: 5), "archived row shown")
        XCTAssertTrue(row(app, 4).label.contains("Archived"), row(app, 4).label)
        row(app, 4).swipeLeft()
        let unarchive = el(app, "habits.unarchive.\(Self.id(4))")
        XCTAssertTrue(unarchive.waitForExistence(timeout: 5))
        unarchive.tap()
        XCTAssertTrue(row(app, 4).waitForExistence(timeout: 5), "unarchived habit is back in the list")
        XCTAssertFalse(row(app, 4).label.contains("Archived"))
    }

    @MainActor
    func testReorderViaEditButton() {
        let app = launch(seed: "typical")
        let edit = el(app, "habits.edit")
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
        guard handles.count >= 2 else {
            XCTFail("no reorder handles in edit mode (found \(handles.count))")
            return
        }
        let first = row(app, 1)
        let before = first.frame.minY
        let source = handles.element(boundBy: 0)
        let target = handles.element(boundBy: 2)
        source.press(forDuration: 0.6, thenDragTo: target)
        edit.tap()
        XCTAssertGreaterThan(row(app, 1).frame.minY, before, "first habit moved down")
    }

    /// The identifier sits on the whole row; the switch is at its right edge.
    private func toggleShowArchived(_ app: XCUIApplication) {
        el(app, "habits.showArchived").coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    private func waitGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: R-STREAK

    @MainActor
    func testStreakCaptionsFromStreaksSeed() {
        let app = launch(seed: "streaks")
        XCTAssertTrue(row(app, 1).waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, 1).label.contains("10 day streak"), row(app, 1).label)
        XCTAssertTrue(row(app, 2).label.contains("3 day streak"), row(app, 2).label)
        XCTAssertTrue(row(app, 3).label.contains("4 week streak"), row(app, 3).label)
        XCTAssertTrue(app.staticTexts["10 d"].exists)
        XCTAssertTrue(app.staticTexts["3 d"].exists)
        XCTAssertTrue(app.staticTexts["4 wk"].exists)
    }

    @MainActor
    func testTogglingInWeekChangesStreakInHabits() {
        let app = launch(seed: "streaks")
        XCTAssertTrue(row(app, 2).label.contains("3 day streak"))
        app.tabBars.buttons["Week"].tap()
        let cell = el(app, "week.cell.\(Self.id(2).uppercased()).2026-11-03")
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "not done")
        cell.tap()
        XCTAssertEqual(cell.value as? String, "done")
        app.tabBars.buttons["Habits"].tap()
        XCTAssertTrue(row(app, 2).waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, 2).label.contains("4 day streak"), row(app, 2).label)
    }

    // MARK: R-A11Y

    @MainActor
    func testAuditHabitsList() throws {
        let app = launch(seed: "typical")
        XCTAssertTrue(row(app, 1).waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA34-1: list fails audit (Contrast nearly passed)", strict: false)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testAuditHabitEditor() throws {
        let app = launch(seed: "typical")
        el(app, "habits.add").tap()
        XCTAssertTrue(el(app, "habits.editor").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA34-2: editor audit (Dynamic Type partially unsupported)", strict: false)
        try app.performAccessibilityAudit()
    }
}

extension XCUIElement {
    /// Replaces the text of a focused text field.
    func clearAndType(_ text: String) {
        guard let current = value as? String else { typeText(text); return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        typeText(text)
    }
}
