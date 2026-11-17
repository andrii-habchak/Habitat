import XCTest

/// R-REM on the Reminders tab. Today is pinned to 2026-11-03; seed `typical` has two reminders:
/// general "Plan the day" 08:00 Mon-Fri, and a habit reminder for Read at 21:00 every day.
/// Ids are from docs/status/p6.md. New reminders default to General, 09:00, all weekdays.
final class RemindersTests: XCTestCase {
    private func rid(_ index: Int) -> String { "00000000-0000-0000-0002-" + String(format: "%012d", index) }

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchReminders(seed: String = "typical") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seed", seed, "-today", "2026-11-03", "-fakeNotifications"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Reminders"].tap()
        XCTAssertTrue(el(app, "reminders.screen").waitForExistence(timeout: 5), "reminders.screen")
        return app
    }

    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func value(_ element: XCUIElement) -> String { (element.value as? String) ?? "" }

    private func openNew(_ app: XCUIApplication) {
        el(app, "reminders.add").tap()
        XCTAssertTrue(el(app, "reminders.editor").waitForExistence(timeout: 5), "editor")
    }

    private func typeLabel(_ app: XCUIApplication, _ text: String) {
        let field = app.textFields["reminders.editor.label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text + " ")  // trailing space commits the word before autocorrect
    }

    private func setWeekdays(_ app: XCUIApplication, selected: Set<Int>) {
        for day in 1...7 {
            let chip = el(app, "reminders.editor.weekday.\(day)")
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "weekday chip \(day)")
            let isOn = value(chip) == "Selected"
            if isOn != selected.contains(day) { chip.tap() }
        }
    }

    private func save(_ app: XCUIApplication) { el(app, "reminders.editor.save").tap() }

    private func waitGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                                timeout: timeout) == .completed
    }

    private func rows(_ app: XCUIApplication) -> [String] {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'reminders.row.'"))
        return query.allElementsBoundByIndex.map { $0.label }
    }

    // MARK: List

    @MainActor
    func testSeededRemindersAreListedWithTargetTimeAndDays() {
        let app = launchReminders()
        let general = el(app, "reminders.row.\(rid(1))")
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        XCTAssertTrue(general.label.contains("Plan the day"), general.label)
        XCTAssertTrue(general.label.contains("8:00") || general.label.contains("08:00"), general.label)
        XCTAssertTrue(general.label.contains("Weekdays"), "Mon-Fri reads as Weekdays: \(general.label)")

        let habit = el(app, "reminders.row.\(rid(2))")
        XCTAssertTrue(habit.exists)
        XCTAssertTrue(habit.label.contains("Read"), habit.label)
        XCTAssertTrue(habit.label.contains("9:00") || habit.label.contains("21:00"), habit.label)
        XCTAssertTrue(habit.label.contains("Every day"), habit.label)
    }

    @MainActor
    func testEmptyStateAndAddOpensEditor() {
        let app = launchReminders(seed: "empty")
        XCTAssertTrue(el(app, "reminders.empty").waitForExistence(timeout: 5))
        openNew(app)
        XCTAssertTrue(el(app, "reminders.editor.save").exists)
        XCTAssertTrue(el(app, "reminders.editor.cancel").exists)
        XCTAssertFalse(el(app, "reminders.editor.delete").exists, "no delete when adding")
        el(app, "reminders.editor.cancel").tap()
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        XCTAssertTrue(el(app, "reminders.empty").exists, "cancel adds nothing")
    }

    // MARK: Add

    @MainActor
    func testAddGeneralReminderWithLabelAndWeekdays() {
        let app = launchReminders(seed: "empty")
        openNew(app)
        typeLabel(app, "Stretch")
        setWeekdays(app, selected: [1, 3, 5])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")), "editor closes after a valid save")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Stretch'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "rows: \(rows(app))")
        for name in ["Monday", "Wednesday", "Friday"] { XCTAssertTrue(row.label.contains(name), row.label) }
        XCTAssertFalse(row.label.contains("Tuesday"), row.label)
        XCTAssertFalse(el(app, "reminders.empty").exists)
    }

    @MainActor
    func testAddHabitReminderForAnActiveHabit() {
        let app = launchReminders()
        openNew(app)
        app.segmentedControls["reminders.editor.kind"].buttons["Habit"].tap()
        XCTAssertTrue(el(app, "reminders.editor.habit").waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["reminders.editor.label"].exists, "no label field for habit reminders")
        setWeekdays(app, selected: [6, 7])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        let row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Habit reminder: Read' AND label CONTAINS 'Weekends'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "rows: \(rows(app))")
    }

    @MainActor
    func testSavingWithNoWeekdayIsRejectedOrDisabled() {
        let app = launchReminders(seed: "empty")
        openNew(app)
        typeLabel(app, "Never")
        setWeekdays(app, selected: [])
        let saveButton = el(app, "reminders.editor.save")
        if saveButton.isEnabled {
            saveButton.tap()
            XCTAssertTrue(el(app, "reminders.editor").exists, "editor stays open")
            XCTAssertTrue(el(app, "reminders.editor.error").waitForExistence(timeout: 3), "an error explains why")
        }
        XCTAssertTrue(el(app, "reminders.editor").exists)
        el(app, "reminders.editor.cancel").tap()
        XCTAssertTrue(el(app, "reminders.empty").waitForExistence(timeout: 5), "nothing was added")
    }

    // MARK: Duplicate / overlap

    @MainActor
    func testDuplicateGeneralReminderIsRejectedWithMessageNamingTheClash() {
        let app = launchReminders(seed: "empty")
        openNew(app)
        typeLabel(app, "Water")
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))

        openNew(app)
        typeLabel(app, "Stretch")  // same time (09:00) and weekdays: clashes whatever the label
        save(app)
        let error = el(app, "reminders.editor.error")
        XCTAssertTrue(error.waitForExistence(timeout: 5), "inline error")
        XCTAssertTrue(el(app, "reminders.editor").exists, "editor stays open on error")
        let text = error.label.isEmpty ? value(error) : error.label
        XCTAssertTrue(text.contains("Water"), "message names the clashing reminder: \(text)")
        el(app, "reminders.editor.cancel").tap()
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        XCTAssertEqual(rows(app).count, 1, "the duplicate was not stored: \(rows(app))")
    }

    @MainActor
    func testNonOverlappingWeekdaysAtSameTimeAreAccepted() {
        let app = launchReminders(seed: "empty")
        openNew(app)
        typeLabel(app, "Weekday")
        setWeekdays(app, selected: [1, 2, 3, 4, 5])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))

        openNew(app)
        typeLabel(app, "Weekend")
        setWeekdays(app, selected: [6, 7])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")), "disjoint weekdays do not clash")
        XCTAssertEqual(rows(app).count, 2, "\(rows(app))")
    }

    @MainActor
    func testPartiallyOverlappingWeekdaysClash() {
        let app = launchReminders(seed: "empty")
        openNew(app)
        typeLabel(app, "Weekday")
        setWeekdays(app, selected: [1, 2, 3, 4, 5])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))

        openNew(app)
        typeLabel(app, "Friday and Saturday")
        setWeekdays(app, selected: [5, 6])
        save(app)
        XCTAssertTrue(el(app, "reminders.editor.error").waitForExistence(timeout: 5), "Friday overlaps")
        // Dropping Friday resolves the clash and the same form can be saved.
        setWeekdays(app, selected: [6])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")), "saved after fixing the overlap")
        XCTAssertEqual(rows(app).count, 2)
    }

    @MainActor
    func testDuplicateHabitReminderForSameHabitIsRejected() {
        // `typical`: Read is preselected and already has a reminder at 21:00, so 09:00 is free once.
        let typical = launchReminders()
        for _ in 0..<2 {
            openNew(typical)
            typical.segmentedControls["reminders.editor.kind"].buttons["Habit"].tap()
            save(typical)
            if el(typical, "reminders.editor.error").waitForExistence(timeout: 3) { break }
            XCTAssertTrue(waitGone(el(typical, "reminders.editor")))
        }
        let error = el(typical, "reminders.editor.error")
        XCTAssertTrue(error.exists, "the second habit reminder at 09:00 every day clashes")
        let text = error.label.isEmpty ? value(error) : error.label
        XCTAssertTrue(text.contains("Read"), "message names the clash: \(text)")
    }

    // MARK: Edit

    @MainActor
    func testEditGeneralReminderLabelAndWeekdays() {
        let app = launchReminders()
        el(app, "reminders.row.\(rid(1))").tap()
        XCTAssertTrue(el(app, "reminders.editor").waitForExistence(timeout: 5))
        XCTAssertTrue(el(app, "reminders.editor.delete").exists, "delete is offered when editing")
        let field = app.textFields["reminders.editor.label"]
        XCTAssertEqual(value(field), "Plan the day")
        XCTAssertEqual(value(el(app, "reminders.editor.weekday.1")), "Selected")
        XCTAssertEqual(value(el(app, "reminders.editor.weekday.6")), "Not selected")
        field.tap()
        field.typeText(" tomorrow ")
        setWeekdays(app, selected: [1, 2, 3, 4, 5, 6])
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        let row = el(app, "reminders.row.\(rid(1))")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Plan the day tomorrow"), row.label)
        XCTAssertTrue(row.label.contains("Saturday"), row.label)
        XCTAssertEqual(rows(app).count, 2, "edit does not duplicate the reminder")
    }

    @MainActor
    func testEditingDoesNotClashWithItself() {
        let app = launchReminders()
        el(app, "reminders.row.\(rid(1))").tap()
        XCTAssertTrue(el(app, "reminders.editor").waitForExistence(timeout: 5))
        save(app)  // unchanged
        XCTAssertTrue(waitGone(el(app, "reminders.editor")), "an unchanged reminder is not its own duplicate")
    }

    @MainActor
    func testCancelEditKeepsOriginal() {
        let app = launchReminders()
        el(app, "reminders.row.\(rid(1))").tap()
        XCTAssertTrue(el(app, "reminders.editor").waitForExistence(timeout: 5))
        setWeekdays(app, selected: [7])
        el(app, "reminders.editor.cancel").tap()
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        XCTAssertTrue(el(app, "reminders.row.\(rid(1))").label.contains("Weekdays"), "original days kept")
    }

    // MARK: Delete

    @MainActor
    func testDeleteFromEditor() {
        let app = launchReminders()
        el(app, "reminders.row.\(rid(1))").tap()
        XCTAssertTrue(el(app, "reminders.editor").waitForExistence(timeout: 5))
        el(app, "reminders.editor.delete").tap()
        // A confirmation may follow; confirm it by its destructive button if present.
        let confirm = app.buttons["Delete"].firstMatch
        if confirm.waitForExistence(timeout: 2) { confirm.tap() }
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        XCTAssertTrue(waitGone(el(app, "reminders.row.\(rid(1))")), "reminder removed")
        XCTAssertTrue(el(app, "reminders.row.\(rid(2))").exists, "other reminder untouched")
    }

    @MainActor
    func testSwipeToDelete() {
        let app = launchReminders()
        let row = el(app, "reminders.row.\(rid(2))")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "swipe action")
        delete.tap()
        XCTAssertTrue(waitGone(el(app, "reminders.row.\(rid(2))")))
        XCTAssertTrue(el(app, "reminders.row.\(rid(1))").exists)
    }

    @MainActor
    func testDeletedReminderCanBeRecreated() {
        // After deleting, the same time/weekdays are free again (no stale duplicate).
        let app = launchReminders(seed: "empty")
        openNew(app)
        typeLabel(app, "Once")
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'reminders.row.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(el(app, "reminders.empty").waitForExistence(timeout: 5))
        openNew(app)
        typeLabel(app, "Again")
        save(app)
        XCTAssertTrue(waitGone(el(app, "reminders.editor")), "no clash with the deleted reminder")
    }

    // MARK: Permission and mark done

    @MainActor
    func testPermissionBannerIsAbsentWhenAuthorized() {
        let app = launchReminders()
        XCTAssertFalse(el(app, "reminders.permissionBanner").exists)
        XCTAssertFalse(el(app, "reminders.syncError").exists)
    }

    // MARK: R-A11Y

    @MainActor
    func testAuditRemindersList() throws {
        let app = launchReminders()
        XCTAssertTrue(el(app, "reminders.row.\(rid(1))").waitForExistence(timeout: 5))
        XCTExpectFailure("BUG-QA57-5: reminders list audit (Contrast nearly passed)", strict: false)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testAuditReminderEditor() throws {
        let app = launchReminders()
        openNew(app)
        XCTExpectFailure("BUG-QA57-6: reminder editor audit (Contrast failed)", strict: false)
        try app.performAccessibilityAudit()
    }
}
