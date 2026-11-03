import Foundation
import HabitatCore
import Testing

@Suite("Goal")
struct GoalTests {
    @Test("R-LIST: weekly goals accept 1...7", arguments: 1...7)
    func validCounts(_ count: Int) throws {
        let goal = try Goal.weekly(count)
        #expect(goal == .timesPerWeek(count))
        #expect(goal.weeklyTarget == count)
    }

    @Test("R-LIST: weekly goals outside 1...7 are rejected", arguments: [0, -1, 8, 100])
    func invalidCounts(_ count: Int) {
        #expect(throws: GoalError.timesPerWeekOutOfRange(count)) { try Goal.weekly(count) }
        #expect(throws: GoalError.self) { try Goal.timesPerWeek(count).validate() }
        #expect(GoalError.timesPerWeekOutOfRange(count).description.contains("\(count)"))
    }

    @Test("R-LIST R-WEEK: daily means 7 per week")
    func daily() throws {
        #expect(Goal.daily.weeklyTarget == 7)
        try Goal.daily.validate()
    }

    @Test("R-DATA: goal JSON round trip", arguments: [Goal.daily, .timesPerWeek(1), .timesPerWeek(7)])
    func codable(_ goal: Goal) throws {
        let data = try JSONEncoder().encode(goal)
        #expect(try JSONDecoder().decode(Goal.self, from: data) == goal)
    }

    @Test("R-DATA: malformed goal JSON is rejected", arguments: [
        #"{"kind":"timesPerWeek","count":9}"#, #"{"kind":"timesPerWeek"}"#, #"{"kind":"monthly"}"#, #"{}"#
    ])
    func malformed(_ json: String) {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Goal.self, from: Data(json.utf8)) }
    }
}

@Suite("Weekly status")
struct WeeklyStatusTests {
    /// (c, N, r, expected) — PLAN §2 table and its boundaries.
    @Test("R-WEEK: status table", arguments: [
        (0, 3, 7, WeeklyStatus.inProgress),  // week just started: never red
        (0, 7, 7, .inProgress),               // daily goal on Monday
        (0, 1, 7, .inProgress),
        (3, 3, 5, .met),                      // c = N
        (4, 3, 2, .met),                      // c > N
        (7, 7, 1, .met),
        (3, 3, 0, .met),                      // finished and met
        (1, 3, 2, .inProgress),               // c + r = N
        (1, 3, 1, .failed),                   // c + r = N - 1
        (6, 7, 1, .inProgress),               // c + r = N on Sunday
        (5, 7, 1, .failed),                   // c + r = N - 1 on Sunday
        (0, 1, 1, .inProgress),               // last chance
        (2, 3, 0, .failed),                   // finished, not met
        (0, 1, 0, .failed),
        (0, 7, 6, .failed)                    // daily goal missed Monday
    // swiftlint:disable:next large_tuple
    ] as [(Int, Int, Int, WeeklyStatus)])
    func table(_ done: Int, _ target: Int, _ daysLeft: Int, _ expected: WeeklyStatus) {
        #expect(WeeklyStatus.evaluate(done: done, target: target, daysLeft: daysLeft) == expected)
    }

    @Test("R-WEEK: progress counts only days of that week")
    func progressCounts() throws {
        let week = Week(containing: day("2026-11-04"))
        let done = days("2026-11-01", "2026-11-02", "2026-11-04", "2026-11-08", "2026-11-09")
        let progress = WeeklyProgress(week: week, goal: try .weekly(3), doneDays: done, today: day("2026-11-04"))
        #expect(progress.done == 3)
        #expect(progress.target == 3)
        #expect(progress.daysLeft == 5)
        #expect(progress.status == .met)
    }

    @Test("R-WEEK: red never just because the week started")
    func notRedAtStart() throws {
        let week = Week(containing: day("2026-11-02"))
        for count in 1...7 {
            let progress = WeeklyProgress(week: week, goal: try .weekly(count), doneDays: [], today: day("2026-11-02"))
            #expect(progress.status == .inProgress)
        }
        let daily = WeeklyProgress(week: week, goal: .daily, doneDays: [], today: day("2026-11-02"))
        #expect(daily.status == .inProgress)
    }

    @Test("R-WEEK: unreachable mid-week turns red, finished week is final")
    func unreachable() throws {
        let week = Week(containing: day("2026-11-02"))
        let goal = try Goal.weekly(5)
        let done = days("2026-11-02")
        // Friday: c = 1, r = 3 → 4 < 5.
        #expect(WeeklyProgress(week: week, goal: goal, doneDays: done, today: day("2026-11-06")).status == .failed)
        // Thursday: c = 1, r = 4 → 5 = N.
        #expect(WeeklyProgress(week: week, goal: goal, doneDays: done, today: day("2026-11-05")).status == .inProgress)
        // Next Monday: finished.
        let finished = WeeklyProgress(week: week, goal: goal, doneDays: done, today: day("2026-11-09"))
        #expect(finished.daysLeft == 0)
        #expect(finished.status == .failed)
    }

    @Test("R-WEEK: a future week is in progress with 7 days left")
    func futureWeek() {
        let week = Week(containing: day("2026-11-16"))
        let progress = WeeklyProgress(week: week, goal: .daily, doneDays: [], today: day("2026-11-04"))
        #expect(progress.daysLeft == 7)
        #expect(progress.status == .inProgress)
    }
}

@Suite("Streaks")
struct StreakTests {
    private let today = day("2026-11-05")  // Thursday; week Nov 2...8
    private let created = day("2026-10-01")

    @Test("R-STREAK: daily streak cases", arguments: [
        (["2026-11-03", "2026-11-04", "2026-11-05"], 3),
        (["2026-11-03", "2026-11-04"], 2),               // today not done: no break
        (["2026-11-01", "2026-11-02", "2026-11-04"], 1), // gap on Nov 3
        (["2026-11-05", "2026-11-03", "2026-11-02"], 1), // today done, gap yesterday
        (["2026-11-03"], 0),                             // yesterday missed
        (["2026-11-05"], 1),
        ([], 0),
        (["2026-11-06", "2026-11-07"], 0)                // future days do not count
    ] as [([String], Int)])
    func daily(_ done: [String], _ expected: Int) {
        let doneDays = Set(done.map { day($0) })
        #expect(Streak.daily(doneDays: doneDays, createdDay: created, today: today) == expected)
        #expect(Streak.current(goal: .daily, doneDays: doneDays, createdDay: created, today: today) == expected)
    }

    @Test("R-STREAK: daily streak starts at the created day")
    func dailyCreated() {
        let done = days("2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05")
        #expect(Streak.daily(doneDays: done, createdDay: day("2026-11-03"), today: today) == 3)
    }

    @Test("R-STREAK R-LIST: archived daily habit is frozen at its archive day")
    func dailyArchived() {
        let done = days("2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-05")
        let frozen = Streak.daily(doneDays: done, createdDay: created, archivedDay: day("2026-11-03"), today: today)
        #expect(frozen == 5)
        let undoneArchiveDay = days("2026-11-01", "2026-11-02")
        #expect(Streak.daily(
            doneDays: undoneArchiveDay, createdDay: created, archivedDay: day("2026-11-03"), today: today
        ) == 2)
        let archivedLater = Streak.daily(
            doneDays: done, createdDay: created, archivedDay: day("2026-11-20"), today: today
        )
        #expect(archivedLater == 1)
    }

    @Test("R-STREAK: weekly streak counts the current week once met")
    func weeklyCurrentMet() throws {
        let done = days(
            "2026-11-02", "2026-11-03", "2026-11-04",  // current: met
            "2026-10-26", "2026-10-27", "2026-10-28",  // previous: met
            "2026-10-19", "2026-10-20"                 // before: 2 of 3
        )
        #expect(Streak.weekly(goal: try .weekly(3), doneDays: done, createdDay: created, today: today) == 2)
        #expect(Streak.current(goal: try .weekly(3), doneDays: done, createdDay: created, today: today) == 2)
    }

    @Test("R-STREAK: weekly streak with the current week unmet does not break")
    func weeklyCurrentUnmet() throws {
        let done = days(
            "2026-11-02",
            "2026-10-26", "2026-10-27", "2026-10-28",
            "2026-10-19", "2026-10-21", "2026-10-25"
        )
        #expect(Streak.weekly(goal: try .weekly(3), doneDays: done, createdDay: created, today: today) == 2)
        // Already failed this week (c = 0, r = 4 < 5): still not a break until the week is judged.
        #expect(Streak.weekly(goal: try .weekly(5), doneDays: [], createdDay: created, today: today) == 0)
    }

    @Test("R-STREAK: an unmet previous week breaks the weekly streak")
    func weeklyGap() throws {
        let done = days(
            "2026-10-26",
            "2026-10-19", "2026-10-20", "2026-10-21"
        )
        #expect(Streak.weekly(goal: try .weekly(3), doneDays: done, createdDay: created, today: today) == 0)
    }

    @Test("R-STREAK: weekly streak stops at the creation week")
    func weeklyCreated() throws {
        let done = days(
            "2026-11-02", "2026-11-03",
            "2026-10-26", "2026-10-27",
            "2026-10-22", "2026-10-23",              // creation week (created Thu Oct 22)
            "2026-10-12", "2026-10-13", "2026-10-14" // before creation: ignored
        )
        let goal = try Goal.weekly(2)
        #expect(Streak.weekly(goal: goal, doneDays: done, createdDay: day("2026-10-22"), today: today) == 3)
        #expect(Streak.weekly(goal: goal, doneDays: [], createdDay: day("2026-11-10"), today: today) == 0)
    }

    @Test("R-STREAK R-LIST: archived weekly habit ignores days after the archive day")
    func weeklyArchived() throws {
        let goal = try Goal.weekly(3)
        let metAtArchive = days("2026-10-26", "2026-10-27", "2026-10-28", "2026-10-19", "2026-10-20", "2026-10-21")
        #expect(Streak.weekly(
            goal: goal, doneDays: metAtArchive, createdDay: created, archivedDay: day("2026-10-28"), today: today
        ) == 2)
        let afterArchive = days("2026-10-26", "2026-10-27", "2026-10-29", "2026-10-19", "2026-10-20", "2026-10-21")
        #expect(Streak.weekly(
            goal: goal, doneDays: afterArchive, createdDay: created, archivedDay: day("2026-10-27"), today: today
        ) == 1)
    }

    @Test("R-STREAK: seven times a week uses the weekly rule")
    func sevenPerWeek() throws {
        let done = Set(Week(containing: day("2026-10-28")).days)
        #expect(Streak.current(goal: try .weekly(7), doneDays: done, createdDay: created, today: today) == 1)
        #expect(Streak.current(goal: .daily, doneDays: done, createdDay: created, today: today) == 0)
    }

    @Test("R-STREAK R-LIST: habit forwards to the streak rules")
    func habitStreak() {
        let value = habit(1, created: "2026-11-01")
        #expect(value.streak(doneDays: days("2026-11-04", "2026-11-05"), today: today) == 2)
    }
}
