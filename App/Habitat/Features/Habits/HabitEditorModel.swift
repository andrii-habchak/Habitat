import Foundation
import HabitatCore
import HabitatData
import Observation

/// Form state for adding or editing a habit.
@MainActor
@Observable
final class HabitEditorModel {
    enum GoalKind: Hashable { case daily, weekly }

    var name: String
    var colorHex: String
    var goalKind: GoalKind
    var weeklyCount: Int
    private(set) var errorMessage: String?

    let editingID: UUID?
    private let habits: HabitRepository

    init(services: AppServices, editing habit: Habit? = nil) {
        habits = services.habitRepository()
        editingID = habit?.id
        name = habit?.name ?? ""
        colorHex = habit?.colorHex ?? Theme.defaultHabitColorHex
        switch habit?.goal ?? .daily {
        case .daily:
            goalKind = .daily
            weeklyCount = 3
        case let .timesPerWeek(count):
            goalKind = .weekly
            weeklyCount = count
        }
    }

    var isEditing: Bool { editingID != nil }

    var goal: Goal {
        goalKind == .daily ? .daily : .timesPerWeek(weeklyCount)
    }

    /// Saves the habit; `false` leaves the message in `errorMessage`.
    func save() -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = HabitError.emptyName.localizedDescription
            return false
        }
        do {
            try goal.validate()
            if let editingID {
                try habits.update(id: editingID, name: trimmed, colorHex: colorHex, goal: goal)
            } else {
                try habits.create(name: trimmed, colorHex: colorHex, goal: goal)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
