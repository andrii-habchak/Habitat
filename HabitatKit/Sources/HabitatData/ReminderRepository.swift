import Foundation
import HabitatCore
import SwiftData

/// Reminders: create, update, delete (R-REM). The duplicate rule of `Reminder.validate` is
/// enforced here; its `ReminderError` (naming the clashing reminder) is thrown as it is.
@MainActor
public final class ReminderRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// All reminders ordered by time, then id.
    public func all() throws -> [Reminder] {
        try models().map(\.value)
            .sorted { ($0.time, $0.id.uuidString) < ($1.time, $1.id.uuidString) }
    }

    @discardableResult
    public func create(kind: ReminderKind, time: ReminderTime, weekdays: Set<Weekday>) throws -> Reminder {
        let reminder = Reminder(kind: kind, time: time, weekdays: weekdays)
        try validate(reminder)
        context.insert(ReminderModel(reminder))
        try save()
        return reminder
    }

    /// Replaces kind, time and weekdays of the reminder with the same id.
    @discardableResult
    public func update(_ reminder: Reminder) throws -> Reminder {
        guard let stored = try model(id: reminder.id) else { throw RepositoryError.reminderNotFound(reminder.id) }
        try validate(reminder)
        stored.apply(reminder)
        try save()
        return reminder
    }

    public func delete(id: UUID) throws {
        guard let stored = try model(id: id) else { throw RepositoryError.reminderNotFound(id) }
        context.delete(stored)
        try save()
    }

    // MARK: - Internals

    private func validate(_ reminder: Reminder) throws {
        let habits = Dictionary(
            try context.fetch(FetchDescriptor<HabitModel>()).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        if let habitID = reminder.kind.habitID, habits[habitID] == nil {
            throw RepositoryError.habitNotFound(habitID)
        }
        try reminder.validate(against: try models().map(\.value)) { habits[$0] }
    }

    private func models() throws -> [ReminderModel] {
        try context.fetch(FetchDescriptor<ReminderModel>())
    }

    private func model(id: UUID) throws -> ReminderModel? {
        var descriptor = FetchDescriptor<ReminderModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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
