import Foundation
import HabitatCore
import SwiftData

/// Completions: toggle a day, query a range (R-LIST, R-STREAK). Queries drop completions on
/// days the habit does not count (after the archive day, before the created day), so
/// donuts and streaks never see them.
@MainActor
public final class CompletionRepository {
    private let context: ModelContext
    private let clock: any Clock

    public init(context: ModelContext, clock: any Clock) {
        self.context = context
        self.clock = clock
    }

    /// Flips done/not done for the habit on `day`; returns the new state.
    /// Refused for a future day and for a day the habit does not count.
    @discardableResult
    public func toggle(habitID: UUID, day: DayKey) throws -> Bool {
        guard let habit = try habitModel(habitID)?.value else { throw RepositoryError.habitNotFound(habitID) }
        guard day <= clock.today else { throw RepositoryError.futureDay(day) }
        guard habit.isActive(on: day) else { throw RepositoryError.habitNotActive(habitID, day) }
        let completion = Completion(habitID: habitID, day: day)
        let isDone: Bool
        if let existing = try model(for: completion) {
            context.delete(existing)
            isDone = false
        } else {
            context.insert(CompletionModel(completion))
            isDone = true
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return isDone
    }

    public func isDone(habitID: UUID, day: DayKey) throws -> Bool {
        guard let habit = try habitModel(habitID)?.value, habit.isActive(on: day) else { return false }
        return try model(for: Completion(habitID: habitID, day: day)) != nil
    }

    /// Completions from `first` through `last` (inclusive), only on days the habit counts,
    /// ordered by day then habit id.
    public func completions(from first: DayKey, through last: DayKey) throws -> [Completion] {
        let low = first.serial
        let high = last.serial
        let descriptor = FetchDescriptor<CompletionModel>(
            predicate: #Predicate { $0.daySerial >= low && $0.daySerial <= high }
        )
        let habits = try habitsByID()
        return try context.fetch(descriptor)
            .map(\.value)
            .filter { habits[$0.habitID]?.isActive(on: $0.day) ?? false }
            .sorted { ($0.day, $0.habitID.uuidString) < ($1.day, $1.habitID.uuidString) }
    }

    /// Days the habit was done, only days it counts. Input for `Habit.streak`.
    public func doneDays(habitID: UUID) throws -> Set<DayKey> {
        guard let habit = try habitModel(habitID)?.value else { return [] }
        let descriptor = FetchDescriptor<CompletionModel>(predicate: #Predicate { $0.habitID == habitID })
        let days = try context.fetch(descriptor).map { DayKey(serial: $0.daySerial) }
        return Set(days.filter { habit.isActive(on: $0) })
    }

    /// Current streak (R-STREAK) of the habit as of the clock's today.
    public func streak(habitID: UUID) throws -> Int {
        guard let habit = try habitModel(habitID)?.value else { throw RepositoryError.habitNotFound(habitID) }
        return habit.streak(doneDays: try doneDays(habitID: habitID), today: clock.today)
    }

    // MARK: - Internals

    private func habitModel(_ id: UUID) throws -> HabitModel? {
        var descriptor = FetchDescriptor<HabitModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func habitsByID() throws -> [UUID: Habit] {
        let habits = try context.fetch(FetchDescriptor<HabitModel>()).map(\.value)
        return Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func model(for completion: Completion) throws -> CompletionModel? {
        let key = CompletionModel.key(for: completion)
        var descriptor = FetchDescriptor<CompletionModel>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
