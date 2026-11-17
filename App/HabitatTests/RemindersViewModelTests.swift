import Foundation
import HabitatCore
import Testing
@testable import Habitat

/// R-REM: grouping and text of the reminders list.
@MainActor
@Suite("Reminders list (R-REM)")
struct RemindersViewModelTests {
    private let today = DayKey("2026-11-04")!
    private let read = Habit(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Read", colorHex: "#3E63DD", goal: .daily, createdDay: DayKey("2026-10-01")!, sortOrder: 0
    )
    private let run = Habit(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Run", colorHex: "#30A46C", goal: .timesPerWeek(3), createdDay: DayKey("2026-10-01")!, sortOrder: 1
    )

    private func time(_ hour: Int, _ minute: Int = 0) -> ReminderTime { ReminderTime(hour: hour, minute: minute)! }

    private func reminder(_ kind: ReminderKind, hour: Int, days: Set<Weekday>) -> Reminder {
        Reminder(kind: kind, time: time(hour), weekdays: days)
    }

    @Test("no reminders give no sections")
    func empty() {
        #expect(RemindersViewModel.sections(reminders: [], habits: [read]).isEmpty)
    }

    @Test("general first, then habits in list order")
    func order() {
        let reminders = [
            reminder(.habit(run.id), hour: 7, days: [.monday]),
            reminder(.general(label: "Water"), hour: 9, days: [.tuesday]),
            reminder(.habit(read.id), hour: 21, days: [.friday])
        ]
        let sections = RemindersViewModel.sections(reminders: reminders, habits: [read, run])
        #expect(sections.map(\.title) == ["General", "Read", "Run"])
        #expect(sections.map(\.id) == ["general", read.id.uuidString, run.id.uuidString])
        #expect(sections.map(\.rows.count) == [1, 1, 1])
    }

    @Test("a habit without reminders gets no section")
    func skipsHabitsWithoutReminders() {
        let sections = RemindersViewModel.sections(
            reminders: [reminder(.habit(run.id), hour: 7, days: [.monday])], habits: [read, run]
        )
        #expect(sections.map(\.title) == ["Run"])
    }

    @Test("reminders of a deleted habit are kept under 'Deleted habit'")
    func orphan() {
        let gone = UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!
        let sections = RemindersViewModel.sections(
            reminders: [reminder(.habit(gone), hour: 7, days: [.monday])], habits: [read]
        )
        #expect(sections.map(\.title) == ["Deleted habit"])
    }

    @Test("archived habit title says archived")
    func archived() {
        var old = read
        old.archivedDay = today
        #expect(RemindersViewModel.habitTitle(old.id, habits: [old]) == "Read (archived)")
    }

    @Test("row title and VoiceOver label")
    func row() {
        let general = RemindersViewModel.row(
            reminder(.general(label: "Water"), hour: 9, days: Set(Weekday.allCases)), habits: []
        )
        #expect(general.title == "Water")
        #expect(general.daysText == "Every day")
        #expect(general.accessibilityLabel.hasPrefix("Reminder: Water, "))
        #expect(general.accessibilityLabel.hasSuffix(", Every day"))

        let forHabit = RemindersViewModel.row(
            reminder(.habit(read.id), hour: 21, days: [.monday, .wednesday]), habits: [read]
        )
        #expect(forHabit.title == "Read")
        #expect(forHabit.accessibilityLabel.hasPrefix("Habit reminder: Read, "))
        #expect(forHabit.accessibilityLabel.hasSuffix(", Monday, Wednesday"))
    }
}

@Suite("ReminderFormat (R-REM)")
struct ReminderFormatTests {
    @Test("summaries for every day, weekdays and weekends")
    func summaries() {
        #expect(ReminderFormat.days(Set(Weekday.allCases)) == "Every day")
        #expect(ReminderFormat.days([.monday, .tuesday, .wednesday, .thursday, .friday]) == "Weekdays")
        #expect(ReminderFormat.days([.saturday, .sunday]) == "Weekends")
        #expect(ReminderFormat.spokenDays([.saturday, .sunday]) == "Weekends")
    }

    @Test("other sets list days Monday first")
    func listed() {
        #expect(ReminderFormat.days([.friday, .monday]) == "Mon, Fri")
        #expect(ReminderFormat.spokenDays([.friday, .monday]) == "Monday, Friday")
    }

    @Test("full names cover every weekday")
    func fullNames() {
        #expect(Weekday.allCases.map(ReminderFormat.fullName) == [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
        ])
    }

    @Test("time text and the Date round trip")
    func timeText() throws {
        let time = try #require(ReminderTime(hour: 7, minute: 5))
        #expect(!ReminderFormat.time(time).isEmpty)
        let date = try #require(ReminderTimeConversion.date(from: time))
        #expect(ReminderTimeConversion.time(from: date) == time)
    }
}
