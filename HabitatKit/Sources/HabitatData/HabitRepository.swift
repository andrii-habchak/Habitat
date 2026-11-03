import Foundation
import HabitatCore
import SwiftData

/// Habits: create, edit, archive, unarchive, reorder (R-LIST). Main-actor, like the
/// `ModelContext` it works on.
@MainActor
public final class HabitRepository {
    private let context: ModelContext
    private let clock: any Clock

    public init(context: ModelContext, clock: any Clock) {
        self.context = context
        self.clock = clock
    }

    /// All habits, archived ones included, in list order.
    public func all() throws -> [Habit] {
        try models().map(\.value)
    }

    /// Habits shown in the list, in list order.
    public func active() throws -> [Habit] {
        try all().filter { !$0.isArchived }
    }

    public func archived() throws -> [Habit] {
        try all().filter(\.isArchived)
    }

    public func habit(id: UUID) throws -> Habit? {
        try model(id: id)?.value
    }

    /// Adds a habit created today at the end of the list.
    @discardableResult
    public func create(name: String, colorHex: String, goal: Goal) throws -> Habit {
        let nextOrder = (try models().map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            goal: goal,
            createdDay: clock.today,
            sortOrder: nextOrder
        )
        try habit.validate()
        context.insert(HabitModel(habit))
        try save()
        return habit
    }

    /// Edits name, colour and goal. Id, created day, archive state and order are kept.
    @discardableResult
    public func update(id: UUID, name: String, colorHex: String, goal: Goal) throws -> Habit {
        let stored = try requireModel(id)
        var habit = stored.value
        habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.colorHex = colorHex
        habit.goal = goal
        try habit.validate()
        stored.apply(habit)
        try save()
        return habit
    }

    /// Archives the habit on `day` (today by default): it stays in history and counts
    /// through that day. Already archived habits are left as they are.
    @discardableResult
    public func archive(id: UUID, on day: DayKey? = nil) throws -> Habit {
        let stored = try requireModel(id)
        let habit = stored.value
        guard !habit.isArchived else { return habit }
        let archived = habit.archived(on: day ?? clock.today)
        try archived.validate()
        stored.apply(archived)
        try save()
        return archived
    }

    /// Brings the habit back to the list at its old position.
    @discardableResult
    public func unarchive(id: UUID) throws -> Habit {
        let stored = try requireModel(id)
        let habit = stored.value.unarchived()
        stored.apply(habit)
        try save()
        return habit
    }

    /// Puts the listed habits first, in the given order; habits not listed (archived ones)
    /// follow in their previous order. An unknown id changes nothing.
    public func reorder(_ orderedIDs: [UUID]) throws {
        let all = try models()
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        var order: [HabitModel] = []
        for id in orderedIDs {
            guard let model = byID[id] else { throw RepositoryError.habitNotFound(id) }
            if seen.insert(id).inserted { order.append(model) }
        }
        order += all.filter { !seen.contains($0.id) }
        for (index, model) in order.enumerated() {
            model.sortOrder = index
        }
        try save()
    }

    // MARK: - Internals

    private func models() throws -> [HabitModel] {
        let descriptor = FetchDescriptor<HabitModel>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdDaySerial)]
        )
        return try context.fetch(descriptor)
    }

    func model(id: UUID) throws -> HabitModel? {
        var descriptor = FetchDescriptor<HabitModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func requireModel(_ id: UUID) throws -> HabitModel {
        guard let model = try model(id: id) else { throw RepositoryError.habitNotFound(id) }
        return model
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
