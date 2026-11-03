import Foundation
import HabitatCore
import HabitatData
import Testing

@MainActor
@Suite("HabitRepository")
struct HabitRepositoryTests {
    @Test("R-LIST: create stores the habit from today, trimmed, at the end of the list")
    func create() throws {
        let store = try TestStore()
        let first = try store.addHabit("  Read  ")
        let second = try store.addHabit("Run", goal: .timesPerWeek(3))
        #expect(first.name == "Read")
        #expect(first.createdDay == testToday)
        #expect(first.sortOrder == 0 && second.sortOrder == 1)
        #expect(try store.habits.active().map(\.name) == ["Read", "Run"])
        #expect(try store.habits.habit(id: second.id)?.goal == .timesPerWeek(3))
    }

    @Test("R-LIST: invalid habits are rejected with the core error and nothing is stored")
    func createInvalid() throws {
        let store = try TestStore()
        #expect(throws: HabitError.emptyName) { try store.habits.create(name: "  ", colorHex: "#112233", goal: .daily) }
        #expect(throws: HabitError.invalidColor("red")) {
            try store.habits.create(name: "A", colorHex: "red", goal: .daily)
        }
        #expect(throws: HabitError.self) {
            try store.habits.create(name: "A", colorHex: "#112233", goal: .timesPerWeek(9))
        }
        #expect(try store.habits.all().isEmpty)
    }

    @Test("R-LIST: edit changes name, colour and goal only")
    func edit() throws {
        let store = try TestStore()
        let habit = try store.addHabit("Read")
        let edited = try store.habits.update(
            id: habit.id, name: "Read more", colorHex: "#FF0000", goal: .timesPerWeek(5)
        )
        #expect(edited.name == "Read more" && edited.colorHex == "#FF0000" && edited.goal == .timesPerWeek(5))
        #expect(edited.id == habit.id && edited.createdDay == habit.createdDay && edited.sortOrder == habit.sortOrder)
        #expect(try store.habits.habit(id: habit.id) == edited)
        #expect(throws: HabitError.emptyName) {
            try store.habits.update(id: habit.id, name: "", colorHex: "#FF0000", goal: .daily)
        }
        #expect(try store.habits.habit(id: habit.id) == edited)
        let missing = UUID()
        #expect(throws: RepositoryError.habitNotFound(missing)) {
            try store.habits.update(id: missing, name: "X", colorHex: "#FF0000", goal: .daily)
        }
    }

    @Test("R-LIST: archive hides the habit from the list, keeps it in history; unarchive restores it in place")
    func archiveUnarchive() throws {
        let store = try TestStore()
        let first = try store.addHabit("A")
        let second = try store.addHabit("B")
        let archived = try store.habits.archive(id: first.id)
        #expect(archived.archivedDay == testToday)
        #expect(try store.habits.active().map(\.id) == [second.id])
        #expect(try store.habits.archived().map(\.id) == [first.id])
        #expect(try store.habits.all().count == 2)

        // A second archive keeps the first archive day.
        let again = try store.habits.archive(id: first.id, on: day("2026-03-10"))
        #expect(again.archivedDay == testToday)

        let restored = try store.habits.unarchive(id: first.id)
        #expect(restored.archivedDay == nil)
        #expect(try store.habits.active().map(\.id) == [first.id, second.id])
    }

    @Test("R-LIST: archiving before the created day is refused")
    func archiveBeforeCreated() throws {
        let store = try TestStore()
        let habit = try store.addHabit()
        #expect(throws: HabitError.self) { try store.habits.archive(id: habit.id, on: day("2026-03-01")) }
        #expect(try store.habits.habit(id: habit.id)?.archivedDay == nil)
    }

    @Test("R-LIST: reorder sets the list order, archived habits follow, unknown ids change nothing")
    func reorder() throws {
        let store = try TestStore()
        let first = try store.addHabit("A")
        let second = try store.addHabit("B")
        let third = try store.addHabit("C")
        let fourth = try store.addHabit("D")
        try store.habits.archive(id: second.id)
        try store.habits.reorder([fourth.id, first.id, third.id])
        #expect(try store.habits.active().map(\.name) == ["D", "A", "C"])
        #expect(try store.habits.all().map(\.name) == ["D", "A", "C", "B"])
        #expect(try store.habits.all().map(\.sortOrder) == [0, 1, 2, 3])

        let before = try store.habits.all()
        #expect(throws: RepositoryError.self) { try store.habits.reorder([third.id, UUID()]) }
        #expect(try store.habits.all() == before)
    }

    @Test("R-LIST: new habits go after the current last order, also after a reorder")
    func createAfterReorder() throws {
        let store = try TestStore()
        let first = try store.addHabit("A")
        let second = try store.addHabit("B")
        try store.habits.reorder([second.id, first.id])
        _ = try store.addHabit("C")
        #expect(try store.habits.active().map(\.name) == ["B", "A", "C"])
    }
}
