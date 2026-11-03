import Foundation
import HabitatCore
import HabitatData
import Observation

/// State of the Habits list: active and archived habits with their streaks as of today.
@MainActor
@Observable
final class HabitsViewModel {
    struct Row: Identifiable, Equatable {
        let habit: Habit
        let streak: Int
        var id: UUID { habit.id }
    }

    private(set) var active: [Row] = []
    private(set) var archived: [Row] = []
    var errorMessage: String?

    private let habits: HabitRepository
    private let completions: CompletionRepository

    init(services: AppServices) {
        habits = services.habitRepository()
        completions = services.completionRepository()
    }

    func load() {
        do {
            let all = try habits.all()
            active = try all.filter { !$0.isArchived }.map(row)
            archived = try all.filter(\.isArchived).map(row)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func archive(id: UUID) -> Bool {
        perform { _ = try habits.archive(id: id) }
    }

    @discardableResult
    func unarchive(id: UUID) -> Bool {
        perform { _ = try habits.unarchive(id: id) }
    }

    /// `onMove` offsets within the active list.
    @discardableResult
    func move(from source: IndexSet, to destination: Int) -> Bool {
        var ids = active.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        return perform { try habits.reorder(ids) }
    }

    /// Returns whether the change was stored.
    private func perform(_ change: () throws -> Void) -> Bool {
        var stored = false
        do {
            try change()
            stored = true
        } catch {
            errorMessage = error.localizedDescription
        }
        load()
        return stored
    }

    private func row(_ habit: Habit) throws -> Row {
        Row(habit: habit, streak: try completions.streak(habitID: habit.id))
    }
}
