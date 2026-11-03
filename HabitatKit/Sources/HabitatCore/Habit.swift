import Foundation

/// A habit as plain values (PLAN §2 lifecycle; persistence lives in HabitatData).
public struct Habit: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// `#RRGGBB`.
    public var colorHex: String
    public var goal: Goal
    /// The first day the habit counts.
    public var createdDay: DayKey
    /// The last day the habit counts; `nil` while it is not archived.
    public var archivedDay: DayKey?
    /// Position in the list, ascending.
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        goal: Goal,
        createdDay: DayKey,
        archivedDay: DayKey? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.goal = goal
        self.createdDay = createdDay
        self.archivedDay = archivedDay
        self.sortOrder = sortOrder
    }

    /// Archived habits are kept in history but hidden from lists.
    public var isArchived: Bool { archivedDay != nil }

    /// `true` from the created day through the archive day (inclusive). Donuts and weekly
    /// counts include the habit only on such days.
    public func isActive(on day: DayKey) -> Bool {
        guard day >= createdDay else { return false }
        if let archivedDay { return day <= archivedDay }
        return true
    }

    /// A copy archived on `day`.
    public func archived(on day: DayKey) -> Habit {
        var copy = self
        copy.archivedDay = day
        return copy
    }

    /// A copy brought back to the lists.
    public func unarchived() -> Habit {
        var copy = self
        copy.archivedDay = nil
        return copy
    }

    /// Current streak (R-STREAK) for the habit's goal, from the days it was done.
    public func streak(doneDays: Set<DayKey>, today: DayKey) -> Int {
        Streak.current(
            goal: goal, doneDays: doneDays, createdDay: createdDay, archivedDay: archivedDay, today: today
        )
    }

    public func validate() throws(HabitError) {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw .emptyName }
        if !Self.isValidColorHex(colorHex) { throw .invalidColor(colorHex) }
        do { try goal.validate() } catch { throw .invalidGoal(error) }
        if let archivedDay, archivedDay < createdDay {
            throw .archivedBeforeCreated(created: createdDay, archived: archivedDay)
        }
    }

    /// `#` followed by six hex digits.
    public static func isValidColorHex(_ text: String) -> Bool {
        guard text.count == 7, text.first == "#" else { return false }
        return text.dropFirst().allSatisfy(\.isHexDigit)
    }
}

/// The fact that a habit was done on a day. No time of day (PLAN §2).
public struct Completion: Hashable, Codable, Sendable {
    public var habitID: UUID
    public var day: DayKey

    public init(habitID: UUID, day: DayKey) {
        self.habitID = habitID
        self.day = day
    }
}

public enum HabitError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyName
    case invalidColor(String)
    case invalidGoal(GoalError)
    case archivedBeforeCreated(created: DayKey, archived: DayKey)

    public var description: String {
        switch self {
        case .emptyName:
            "A habit needs a name."
        case let .invalidColor(text):
            "\"\(text)\" is not a colour (expected #RRGGBB)."
        case let .invalidGoal(error):
            error.description
        case let .archivedBeforeCreated(created, archived):
            "A habit cannot be archived (\(archived)) before it was created (\(created))."
        }
    }
}

extension HabitError: LocalizedError {
    /// Same text as `description`, so `localizedDescription` and alerts show it.
    public var errorDescription: String? { description }
}
