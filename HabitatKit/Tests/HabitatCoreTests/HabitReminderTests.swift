import Foundation
import HabitatCore
import Testing

@Suite("Habit lifecycle")
struct HabitTests {
    @Test("R-LIST R-MONTH: active from the created day through the archive day")
    func activeDays() {
        let open = habit(1, created: "2026-11-03")
        #expect(!open.isActive(on: day("2026-11-02")))
        #expect(open.isActive(on: day("2026-11-03")))
        #expect(open.isActive(on: day("2030-01-01")))
        #expect(!open.isArchived)

        let closed = open.archived(on: day("2026-11-10"))
        #expect(closed.isArchived)
        #expect(closed.isActive(on: day("2026-11-10")))
        #expect(!closed.isActive(on: day("2026-11-11")))
        #expect(!closed.unarchived().isArchived)
        #expect(closed.unarchived().isActive(on: day("2026-11-11")))
    }

    @Test("R-LIST: a valid habit passes validation")
    func valid() throws {
        try habit(1, goal: .timesPerWeek(3), archived: "2026-01-01").validate()
    }

    @Test("R-LIST: invalid habits name the problem")
    func invalid() {
        var value = habit(1)
        value.name = "  \n"
        #expect(throws: HabitError.emptyName) { try value.validate() }

        value = habit(1)
        value.colorHex = "blue"
        #expect(throws: HabitError.invalidColor("blue")) { try value.validate() }

        value = habit(1, goal: .timesPerWeek(0))
        #expect(throws: HabitError.invalidGoal(.timesPerWeekOutOfRange(0))) { try value.validate() }

        value = habit(1, created: "2026-11-03", archived: "2026-11-02")
        #expect(throws: HabitError.self) { try value.validate() }

        #expect(HabitError.emptyName.description.contains("name"))
        #expect(HabitError.invalidColor("x").description.contains("#RRGGBB"))
        #expect(HabitError.invalidGoal(.timesPerWeekOutOfRange(9)).description.contains("9"))
        #expect(HabitError.archivedBeforeCreated(created: day("2026-11-03"), archived: day("2026-11-02"))
            .description.contains("2026-11-02"))
    }

    @Test("R-LIST: colour format", arguments: [
        ("#3366CC", true), ("#abcdef", true), ("#12345", false), ("3366CC", false), ("#GG0000", false),
        ("#3366CC0", false)
    ] as [(String, Bool)])
    func colors(_ text: String, _ valid: Bool) {
        #expect(Habit.isValidColorHex(text) == valid)
    }
}

@Suite("Reminders")
struct ReminderTests {
    private func general(
        _ index: Int, _ label: String = "Water", at hour: Int = 8, _ minute: Int = 0, on days: Set<Weekday>
    ) -> Reminder {
        Reminder(id: uuid(100 + index), kind: .general(label: label), time: time(hour, minute), weekdays: days)
    }

    private func forHabit(_ index: Int, habit habitIndex: Int, at hour: Int = 8, on days: Set<Weekday>) -> Reminder {
        Reminder(id: uuid(100 + index), kind: .habit(uuid(habitIndex)), time: time(hour, 0), weekdays: days)
    }

    @Test("R-REM: times of day are validated", arguments: [(-1, 0), (24, 0), (0, 60), (12, -1)] as [(Int, Int)])
    func invalidTime(_ hour: Int, _ minute: Int) {
        #expect(ReminderTime(hour: hour, minute: minute) == nil)
    }

    @Test("R-REM: time text and order")
    func timeText() {
        #expect(time(8, 5).text == "08:05")
        #expect(time(23, 59).text == "23:59")
        #expect(time(0, 0).minuteOfDay == 0)
        #expect(time(7, 59) < time(8, 0))
    }

    @Test("R-REM: same kind, target, time and an overlapping weekday clash")
    func duplicate() {
        let existing = general(1, "Water", on: [.monday, .wednesday])
        let candidate = general(2, "Stretch", on: [.wednesday, .friday])
        #expect(candidate.clashes(with: existing))
        #expect(throws: ReminderError.duplicate(
            of: existing.id, message: "Clashes with the reminder \"Water\" at 08:00 on Mon, Wed."
        )) {
            try candidate.validate(against: [existing])
        }
    }

    @Test("R-REM: no clash when time, weekdays, kind or target differ")
    func noClash() throws {
        let existing = general(1, on: [.monday, .wednesday])
        try general(2, at: 8, 1, on: [.monday]).validate(against: [existing])
        try general(3, on: [.tuesday, .thursday]).validate(against: [existing])
        try forHabit(4, habit: 1, on: [.monday]).validate(against: [existing])
        try forHabit(5, habit: 2, on: [.monday]).validate(against: [forHabit(6, habit: 1, on: [.monday])])
    }

    @Test("R-REM: habit reminders clash for the same habit and name it")
    func habitDuplicate() {
        let existing = forHabit(1, habit: 7, on: Set(Weekday.allCases))
        let candidate = forHabit(2, habit: 7, on: [.sunday])
        let names = [uuid(7): "Read"]
        let allDays = "Mon, Tue, Wed, Thu, Fri, Sat, Sun."
        #expect(throws: ReminderError.duplicate(
            of: existing.id, message: "Clashes with the reminder for \"Read\" at 08:00 on " + allDays
        )) {
            try candidate.validate(against: [existing]) { names[$0] }
        }
        #expect(throws: ReminderError.duplicate(
            of: existing.id, message: "Clashes with a reminder for this habit at 08:00 on " + allDays
        )) {
            try candidate.validate(against: [existing])
        }
    }

    @Test("R-REM: editing a reminder does not clash with its own old version")
    func editSelf() throws {
        let original = general(1, on: [.monday])
        var edited = original
        edited.weekdays = [.monday, .tuesday]
        try edited.validate(against: [original])
        #expect(!edited.clashes(with: original))
    }

    @Test("R-REM: weekdays are required, general reminders need a label")
    func requiredFields() {
        #expect(throws: ReminderError.noWeekdays) { try general(1, on: []).validate(against: []) }
        #expect(throws: ReminderError.emptyLabel) { try general(1, " ", on: [.monday]).validate(against: []) }
        #expect(ReminderError.noWeekdays.description.contains("weekday"))
        #expect(ReminderError.emptyLabel.description.contains("label"))
        #expect(ReminderError.duplicate(of: uuid(1), message: "m").description == "m")
    }

    @Test("R-REM R-DATA: reminder JSON round trip, weekdays sorted")
    func codable() throws {
        let reminders = [general(1, on: [.sunday, .monday]), forHabit(2, habit: 3, on: [.friday])]
        let data = try JSONEncoder().encode(reminders)
        #expect(try JSONDecoder().decode([Reminder].self, from: data) == reminders)
        #expect(String(bytes: data, encoding: .utf8)?.contains("[1,7]") == true)
        #expect(reminders[0].kind.habitID == nil)
        #expect(reminders[1].kind.habitID == uuid(3))
    }
}
