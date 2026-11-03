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

    func archive(id: UUID) {
        perform { _ = try habits.archive(id: id) }
    }

    func unarchive(id: UUID) {
        perform { _ = try habits.unarchive(id: id) }
    }

    /// `onMove` offsets within the active list.
    func move(from source: IndexSet, to destination: Int) {
        var ids = active.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        perform { try habits.reorder(ids) }
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            errorMessage = error.localizedDescription
        }
        load()
    }

    private func row(_ habit: Habit) throws -> Row {
        Row(habit: habit, streak: try completions.streak(habitID: habit.id))
    }
}
