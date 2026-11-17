import HabitatCore
import Testing
@testable import Habitat

/// R-WEEK, R-STREAK: the week row builder. Week of 2026-11-02 (Mon) to 2026-11-08 (Sun).
@Suite("HabitWeekRow.make (R-WEEK, R-STREAK)")
struct HabitWeekRowTests {
    private let week = Week(containing: DayKey("2026-11-04")!)
    private let wednesday = DayKey("2026-11-04")!

    private func day(_ text: String) -> DayKey { DayKey(text)! }

    private func habit(_ goal: Goal, created: String = "2026-10-01", archived: String? = nil) -> Habit {
        Habit(
            name: "Read", colorHex: "#3E63DD", goal: goal, createdDay: day(created),
            archivedDay: archived.map(day)
        )
    }

    @Test("seven cells Monday to Sunday; future days are disabled")
    func cells() {
        let row = HabitWeekRow.make(
            habit: habit(.daily), week: week, doneDays: [day("2026-11-02")], today: wednesday
        )
        #expect(row.cells.map(\.day) == week.days)
        #expect(row.cells.map(\.isEnabled) == [true, true, true, false, false, false, false])
        #expect(row.cells.map(\.isDone) == [true, false, false, false, false, false, false])
    }

    @Test("days before the habit existed are disabled and never done")
    func beforeCreation() {
        let row = HabitWeekRow.make(
            habit: habit(.daily, created: "2026-11-04"), week: week, doneDays: [day("2026-11-02")], today: wednesday
        )
        #expect(row.cells.map(\.isEnabled) == [false, false, true, false, false, false, false])
        #expect(row.cells[0].isDone == false)
    }

    @Test("days after the archive day are disabled")
    func afterArchive() {
        let row = HabitWeekRow.make(
            habit: habit(.daily, archived: "2026-11-03"), week: week, doneDays: [], today: wednesday
        )
        #expect(row.cells.map(\.isEnabled) == [true, true, false, false, false, false, false])
    }

    @Test("daily habits have no weekly progress")
    func dailyNoProgress() {
        let row = HabitWeekRow.make(habit: habit(.daily), week: week, doneDays: [], today: wednesday)
        #expect(row.progress == nil)
        #expect(!row.isWeekly)
    }

    @Test("weekly habits count c/N with the weekly status")
    func weeklyProgress() throws {
        let row = HabitWeekRow.make(
            habit: habit(.timesPerWeek(2)), week: week,
            doneDays: [day("2026-11-02"), day("2026-11-03")], today: wednesday
        )
        let progress = try #require(row.progress)
        #expect(progress.done == 2)
        #expect(progress.target == 2)
        #expect(progress.status == .met)
        #expect(row.isWeekly)
    }

    @Test("streak is taken as of today")
    func streak() {
        let row = HabitWeekRow.make(
            habit: habit(.daily), week: week,
            doneDays: [day("2026-11-02"), day("2026-11-03"), day("2026-11-04")], today: wednesday
        )
        #expect(row.streak == 3)
    }
}

/// R-LIST, R-STREAK: texts of the habit list.
@Suite("HabitFormat (R-LIST, R-STREAK)")
struct HabitFormatTests {
    @Test("goal text")
    func goalText() {
        #expect(HabitFormat.goalText(.daily) == "Every day")
        #expect(HabitFormat.goalText(.timesPerWeek(1)) == "Once a week")
        #expect(HabitFormat.goalText(.timesPerWeek(4)) == "4 times a week")
    }

    @Test("streak text counts days for daily and weeks for weekly goals")
    func streakText() {
        #expect(HabitFormat.streakText(0, goal: .daily) == "No streak")
        #expect(HabitFormat.streakText(1, goal: .daily) == "1 day streak")
        #expect(HabitFormat.streakText(10, goal: .daily) == "10 day streak")
        #expect(HabitFormat.streakText(1, goal: .timesPerWeek(3)) == "1 week streak")
        #expect(HabitFormat.streakText(4, goal: .timesPerWeek(3)) == "4 week streak")
    }

    @Test("short streak caption")
    func shortStreak() {
        #expect(HabitFormat.shortStreak(3, goal: .daily) == "3 d")
        #expect(HabitFormat.shortStreak(4, goal: .timesPerWeek(2)) == "4 wk")
    }

    @Test("VoiceOver label joins name, goal and streak, and marks archived")
    func accessibilityLabel() {
        #expect(
            HabitFormat.accessibilityLabel(name: "Read", goal: .daily, streak: 3, archived: false)
                == "Read, Every day, 3 day streak"
        )
        #expect(
            HabitFormat.accessibilityLabel(name: "Run", goal: .timesPerWeek(3), streak: 0, archived: true)
                == "Run, 3 times a week, No streak, Archived"
        )
    }
}
