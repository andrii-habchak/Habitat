import Foundation
import HabitatCore
import HabitatData
import Testing

@MainActor
@Suite("ReminderRepository")
struct ReminderRepositoryTests {
    private let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    @Test("R-REM: create, list and delete general and habit reminders")
    func crud() throws {
        let store = try TestStore()
        let habit = try store.addHabit("Read")
        let general = try store.reminders.create(kind: .general(label: "Plan"), time: time(9, 0), weekdays: workdays)
        let forHabit = try store.reminders.create(kind: .habit(habit.id), time: time(8, 0), weekdays: [.saturday])
        #expect(try store.reminders.all() == [forHabit, general])

        var edited = general
        edited.time = time(10, 30)
        edited.weekdays = [.monday]
        #expect(try store.reminders.update(edited) == edited)
        #expect(try store.reminders.all().contains(edited))

        try store.reminders.delete(id: general.id)
        #expect(try store.reminders.all() == [forHabit])
        #expect(throws: RepositoryError.reminderNotFound(general.id)) { try store.reminders.delete(id: general.id) }
    }

    @Test("R-REM: a duplicate habit reminder is rejected and the message names the clash")
    func duplicateHabit() throws {
        let store = try TestStore()
        let habit = try store.addHabit("Read")
        try store.reminders.create(kind: .habit(habit.id), time: time(8, 0), weekdays: [.monday, .wednesday])
        do {
            try store.reminders.create(kind: .habit(habit.id), time: time(8, 0), weekdays: [.wednesday, .friday])
            Issue.record("expected a duplicate error")
        } catch let error as ReminderError {
            guard case let .duplicate(_, message) = error else { Issue.record("wrong error \(error)"); return }
            #expect(message.contains("Read") && message.contains("08:00"))
            #expect(error.localizedDescription == message)
        }
        #expect(try store.reminders.all().count == 1)
        // Another time, other weekdays, or another habit are fine.
        try store.reminders.create(kind: .habit(habit.id), time: time(8, 1), weekdays: [.monday])
        try store.reminders.create(kind: .habit(habit.id), time: time(8, 0), weekdays: [.tuesday])
        let other = try store.addHabit("Run")
        try store.reminders.create(kind: .habit(other.id), time: time(8, 0), weekdays: [.monday])
        #expect(try store.reminders.all().count == 4)
    }

    @Test("R-REM: two general reminders at the same time on a shared weekday clash")
    func duplicateGeneral() throws {
        let store = try TestStore()
        try store.reminders.create(kind: .general(label: "Water"), time: time(8, 0), weekdays: workdays)
        #expect(throws: ReminderError.self) {
            try store.reminders.create(kind: .general(label: "Stretch"), time: time(8, 0), weekdays: [.friday, .sunday])
        }
        #expect(try store.reminders.all().count == 1)
    }

    @Test("R-REM: a duplicating update is rejected, the old reminder stays, and an edit does not clash with itself")
    func updateDuplicate() throws {
        let store = try TestStore()
        let first = try store.reminders.create(kind: .general(label: "A"), time: time(8, 0), weekdays: [.monday])
        let second = try store.reminders.create(kind: .general(label: "B"), time: time(9, 0), weekdays: [.monday])
        var moved = second
        moved.time = time(8, 0)
        #expect(throws: ReminderError.self) { try store.reminders.update(moved) }
        #expect(try store.reminders.all().contains(second))
        var renamed = first
        renamed.kind = .general(label: "A2")
        try store.reminders.update(renamed)
        #expect(try store.reminders.all().contains(renamed))
    }

    @Test("R-REM: no weekdays, blank label, unknown habit and unknown reminder are refused")
    func refusals() throws {
        let store = try TestStore()
        #expect(throws: ReminderError.noWeekdays) {
            try store.reminders.create(kind: .general(label: "A"), time: time(8, 0), weekdays: [])
        }
        #expect(throws: ReminderError.emptyLabel) {
            try store.reminders.create(kind: .general(label: " "), time: time(8, 0), weekdays: [.monday])
        }
        let ghost = UUID()
        #expect(throws: RepositoryError.habitNotFound(ghost)) {
            try store.reminders.create(kind: .habit(ghost), time: time(8, 0), weekdays: [.monday])
        }
        let phantom = Reminder(kind: .general(label: "A"), time: time(8, 0), weekdays: [.monday])
        #expect(throws: RepositoryError.reminderNotFound(phantom.id)) { try store.reminders.update(phantom) }
        #expect(try store.reminders.all().isEmpty)
    }

    @Test("R-REM: weekdays and time survive storage")
    func storageRoundTrip() throws {
        let store = try TestStore()
        let days = Set(Weekday.allCases)
        let created = try store.reminders.create(kind: .general(label: "All"), time: time(23, 59), weekdays: days)
        #expect(try store.reminders.all() == [created])
        #expect(try store.reminders.all().first?.weekdays == days)
    }
}
