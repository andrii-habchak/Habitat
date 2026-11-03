import Foundation
import HabitatCore
import SwiftData

/// How an import treats what is already in the store.
public enum ImportMode: Sendable {
    /// Add what is new; records whose id exists already are kept as they are.
    case merge
    /// Make the store equal to the file.
    case replace
}

/// What an import changed.
public struct ImportSummary: Equatable, Sendable {
    public var habitsAdded = 0
    public var completionsAdded = 0
    public var remindersAdded = 0
    public var habitsRemoved = 0
    public var completionsRemoved = 0
    public var remindersRemoved = 0

    public init(
        habitsAdded: Int = 0, completionsAdded: Int = 0, remindersAdded: Int = 0,
        habitsRemoved: Int = 0, completionsRemoved: Int = 0, remindersRemoved: Int = 0
    ) {
        self.habitsAdded = habitsAdded
        self.completionsAdded = completionsAdded
        self.remindersAdded = remindersAdded
        self.habitsRemoved = habitsRemoved
        self.completionsRemoved = completionsRemoved
        self.remindersRemoved = remindersRemoved
    }
}

/// Reads the whole store as an `ExportDocument` and writes one back. Validation always
/// happens before the first change, and a failed save is rolled back, so an import is
/// all or nothing.
@MainActor
struct DocumentStore {
    let context: ModelContext

    func export() throws -> ExportDocument {
        let habits = try context.fetch(FetchDescriptor<HabitModel>(sortBy: [SortDescriptor(\.sortOrder)]))
            .map(\.value)
        let completions = try context.fetch(FetchDescriptor<CompletionModel>())
            .map(\.value)
            .sorted { ($0.day, $0.habitID.uuidString) < ($1.day, $1.habitID.uuidString) }
        let reminders = try context.fetch(FetchDescriptor<ReminderModel>())
            .map(\.value)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        return ExportDocument(habits: habits, completions: completions, reminders: reminders)
    }

    @discardableResult
    func merge(_ document: ExportDocument) throws -> ImportSummary {
        try ExportCodec.validate(document)
        let current = try export()
        let knownHabits = Set(current.habits.map(\.id))
        let knownReminders = Set(current.reminders.map(\.id))

        // Reminder clashes are checked against the store as well as the file, in file order.
        var names = Dictionary(current.habits.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        for habit in document.habits where names[habit.id] == nil { names[habit.id] = habit.name }
        var accepted = current.reminders
        var newReminders: [Reminder] = []
        for (index, reminder) in document.reminders.enumerated() where !knownReminders.contains(reminder.id) {
            do {
                try reminder.validate(against: accepted) { names[$0] }
            } catch {
                throw ImportError.invalidReminder(index: index, reason: error.description)
            }
            accepted.append(reminder)
            newReminders.append(reminder)
        }

        let firstOrder = (current.habits.map(\.sortOrder).max() ?? -1) + 1
        let newHabits = document.habits
            .filter { !knownHabits.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .enumerated()
            .map { offset, habit in
                var copy = habit
                copy.sortOrder = firstOrder + offset
                return copy
            }
        let knownCompletions = Set(current.completions)
        let newCompletions = document.completions.filter { !knownCompletions.contains($0) }

        for habit in newHabits { context.insert(HabitModel(habit)) }
        for completion in newCompletions { context.insert(CompletionModel(completion)) }
        for reminder in newReminders { context.insert(ReminderModel(reminder)) }
        try save()
        return ImportSummary(
            habitsAdded: newHabits.count, completionsAdded: newCompletions.count, remindersAdded: newReminders.count
        )
    }

    @discardableResult
    func replace(with document: ExportDocument) throws -> ImportSummary {
        try ExportCodec.validate(document)
        var summary = ImportSummary()

        // Records that stay are updated in place; only the rest is deleted or inserted
        // (unique ids make delete-and-reinsert in one save unsafe).
        let habitModels = try context.fetch(FetchDescriptor<HabitModel>())
        let wantedHabits = Dictionary(document.habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var existingHabits = Set<UUID>()
        for model in habitModels {
            if let habit = wantedHabits[model.id] {
                model.apply(habit)
                existingHabits.insert(model.id)
            } else {
                context.delete(model)
                summary.habitsRemoved += 1
            }
        }
        for habit in document.habits where !existingHabits.contains(habit.id) {
            context.insert(HabitModel(habit))
            summary.habitsAdded += 1
        }

        try replaceCompletions(document.completions, summary: &summary)

        let wantedReminders = Dictionary(
            document.reminders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        var existingReminders = Set<UUID>()
        for model in try context.fetch(FetchDescriptor<ReminderModel>()) {
            if let reminder = wantedReminders[model.id] {
                model.apply(reminder)
                existingReminders.insert(model.id)
            } else {
                context.delete(model)
                summary.remindersRemoved += 1
            }
        }
        for reminder in document.reminders where !existingReminders.contains(reminder.id) {
            context.insert(ReminderModel(reminder))
            summary.remindersAdded += 1
        }
        try save()
        return summary
    }

    private func replaceCompletions(_ completions: [Completion], summary: inout ImportSummary) throws {
        let wantedCompletions = Set(completions.map(CompletionModel.key(for:)))
        var existingCompletions = Set<String>()
        for model in try context.fetch(FetchDescriptor<CompletionModel>()) {
            if wantedCompletions.contains(model.key) {
                existingCompletions.insert(model.key)
            } else {
                context.delete(model)
                summary.completionsRemoved += 1
            }
        }
        for completion in completions
        where !existingCompletions.contains(CompletionModel.key(for: completion)) {
            context.insert(CompletionModel(completion))
            summary.completionsAdded += 1
        }
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

/// JSON export and import for the store (R-DATA).
@MainActor
public final class DataTransfer {
    private let store: DocumentStore

    public init(context: ModelContext) {
        store = DocumentStore(context: context)
    }

    /// The whole store as an export document (completions unfiltered, so the file is lossless).
    public func exportDocument() throws -> ExportDocument {
        try store.export()
    }

    /// The export file contents.
    public func exportData() throws -> Data {
        try ExportCodec.encode(try store.export())
    }

    /// Validates `data` completely, then applies it. On any error (`ImportError` for a bad
    /// file or a reminder clash) the store is unchanged.
    @discardableResult
    public func importData(_ data: Data, mode: ImportMode) throws -> ImportSummary {
        let document = try ExportCodec.decode(data)
        switch mode {
        case .merge: return try store.merge(document)
        case .replace: return try store.replace(with: document)
        }
    }
}
