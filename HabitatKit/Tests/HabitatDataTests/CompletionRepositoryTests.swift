import Foundation
import HabitatCore
import HabitatData
import Testing

@MainActor
@Suite("CompletionRepository")
struct CompletionRepositoryTests {
    @Test("R-LIST R-WEEK: toggle marks a day done, a second toggle clears it")
    func toggle() throws {
        let store = try TestStore()
        let habit = try store.addHabit()
        #expect(try store.completions.toggle(habitID: habit.id, day: testToday) == true)
        #expect(try store.completions.isDone(habitID: habit.id, day: testToday))
        #expect(try store.completions.toggle(habitID: habit.id, day: testToday) == false)
        #expect(try store.completions.isDone(habitID: habit.id, day: testToday) == false)
        #expect(try store.snapshot().completions.isEmpty)
    }

    @Test("R-WEEK: a future day and an unknown habit are refused")
    func refusals() throws {
        let store = try TestStore()
        let habit = try store.addHabit()
        let tomorrow = testToday.adding(days: 1)
        #expect(throws: RepositoryError.futureDay(tomorrow)) {
            try store.completions.toggle(habitID: habit.id, day: tomorrow)
        }
        let missing = UUID()
        #expect(throws: RepositoryError.habitNotFound(missing)) {
            try store.completions.toggle(habitID: missing, day: testToday)
        }
        #expect(try store.snapshot().completions.isEmpty)
    }

    @Test("R-LIST: a day before the created day is refused")
    func beforeCreated() throws {
        let store = try TestStore()
        let habit = try store.addHabit()
        let earlier = testToday.adding(days: -1)
        #expect(throws: RepositoryError.habitNotActive(habit.id, earlier)) {
            try store.completions.toggle(habitID: habit.id, day: earlier)
        }
    }

    @Test("R-LIST R-MONTH: range query is inclusive, sorted, and spans several habits")
    func rangeQuery() throws {
        let store = try TestStore(today: day("2026-03-20"))
        let first = try store.addHabit("A")
        let second = try store.addHabit("B")
        // Created on the 20th: back-fill through an import-style document instead.
        let early = ExportDocument(
            habits: [
                Habit(
                    id: first.id, name: "A", colorHex: "#3366CC", goal: .daily,
                    createdDay: day("2026-03-01"), sortOrder: 0
                ),
                Habit(
                    id: second.id, name: "B", colorHex: "#3366CC", goal: .daily,
                    createdDay: day("2026-03-01"), sortOrder: 1
                )
            ],
            completions: [
                Completion(habitID: first.id, day: day("2026-03-09")),
                Completion(habitID: first.id, day: day("2026-03-10")),
                Completion(habitID: second.id, day: day("2026-03-10")),
                Completion(habitID: second.id, day: day("2026-03-12")),
                Completion(habitID: first.id, day: day("2026-03-13"))
            ]
        )
        try store.transfer.importData(ExportCodec.encode(early), mode: .replace)
        let result = try store.completions.completions(from: day("2026-03-10"), through: day("2026-03-12"))
        #expect(result.map(\.day.text) == ["2026-03-10", "2026-03-10", "2026-03-12"])
        #expect(Set(result.map(\.habitID)) == [first.id, second.id])
    }

    @Test("R-LIST R-STREAK: completions after the archive day are ignored by queries and streaks")
    func archiveCutsCompletions() throws {
        let store = try TestStore(today: day("2026-03-20"))
        let habit = Habit(id: UUID(), name: "A", colorHex: "#3366CC", goal: .daily, createdDay: day("2026-03-01"),
                          archivedDay: day("2026-03-12"), sortOrder: 0)
        let completions = [10, 11, 12, 13, 14].map { Completion(habitID: habit.id, day: day("2026-03-\($0)")) }
        try store.transfer.importData(
            ExportCodec.encode(ExportDocument(habits: [habit], completions: completions)), mode: .replace
        )
        let range = try store.completions.completions(from: day("2026-03-01"), through: day("2026-03-31"))
        #expect(range.map(\.day.text) == ["2026-03-10", "2026-03-11", "2026-03-12"])
        #expect(try store.completions.doneDays(habitID: habit.id).count == 3)
        #expect(try store.completions.isDone(habitID: habit.id, day: day("2026-03-13")) == false)
        #expect(try store.completions.streak(habitID: habit.id) == 3)
        // The export keeps everything, so nothing is lost.
        #expect(try store.snapshot().completions.count == 5)
        // New toggles after the archive day are refused.
        #expect(throws: RepositoryError.habitNotActive(habit.id, day("2026-03-15"))) {
            try store.completions.toggle(habitID: habit.id, day: day("2026-03-15"))
        }
    }

    @Test("R-STREAK: unarchiving makes later completions count again")
    func unarchiveRestores() throws {
        let store = try TestStore(today: day("2026-03-20"))
        let habit = Habit(id: UUID(), name: "A", colorHex: "#3366CC", goal: .daily, createdDay: day("2026-03-01"),
                          archivedDay: day("2026-03-12"), sortOrder: 0)
        let completions = [11, 12, 13].map { Completion(habitID: habit.id, day: day("2026-03-\($0)")) }
        try store.transfer.importData(
            ExportCodec.encode(ExportDocument(habits: [habit], completions: completions)), mode: .replace
        )
        try store.habits.unarchive(id: habit.id)
        #expect(try store.completions.doneDays(habitID: habit.id).count == 3)
    }

    @Test("R-STREAK: streak through the repository matches the core rule")
    func streak() throws {
        let store = try TestStore()
        let habit = try store.addHabit()
        #expect(try store.completions.streak(habitID: habit.id) == 0)
        try store.completions.toggle(habitID: habit.id, day: testToday)
        #expect(try store.completions.streak(habitID: habit.id) == 1)
    }

    @Test("R-LIST: completions of other habits are untouched by a toggle")
    func independentHabits() throws {
        let store = try TestStore()
        let first = try store.addHabit("A")
        let second = try store.addHabit("B")
        try store.completions.toggle(habitID: first.id, day: testToday)
        try store.completions.toggle(habitID: second.id, day: testToday)
        try store.completions.toggle(habitID: first.id, day: testToday)
        #expect(try store.completions.doneDays(habitID: first.id).isEmpty)
        #expect(try store.completions.doneDays(habitID: second.id) == [testToday])
    }
}
