import Foundation
import HabitatCore
import HabitatData
import Observation

/// Editor state for a new or an existing reminder. Saving goes through
/// `ReminderRepository`, so the HabitatCore duplicate rule applies (R-REM).
@MainActor
@Observable
final class ReminderEditorModel {
    enum Kind: String, CaseIterable, Identifiable {
        case general
        case habit

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .habit: "Habit"
            }
        }
    }

    var kind: Kind
    var label: String
    var habitID: UUID?
    var time: Date
    var weekdays: Set<Weekday>
    /// Readable reason the last save was refused (names the clashing reminder).
    private(set) var errorMessage: String?

    /// Habits the picker offers: active ones, plus the edited reminder's habit if archived.
    let habitChoices: [Habit]
    /// `nil` for a new reminder.
    let editing: Reminder?

    @ObservationIgnored private let services: AppServices

    static let defaultTime = ReminderTime(hour: 9, minute: 0)

    init(services: AppServices, editing: Reminder?, habits: [Habit]) {
        self.services = services
        self.editing = editing
        let active = habits.filter { !$0.isArchived }
        if let habitID = editing?.kind.habitID, !active.contains(where: { $0.id == habitID }),
           let current = habits.first(where: { $0.id == habitID }) {
            habitChoices = active + [current]
        } else {
            habitChoices = active
        }
        let reminderTime = editing?.time ?? Self.defaultTime
        time = reminderTime.flatMap(ReminderTimeConversion.date(from:)) ?? Date()
        weekdays = editing?.weekdays ?? Set(Weekday.allCases)
        switch editing?.kind {
        case let .general(text):
            kind = .general
            label = text
            habitID = active.first?.id
        case let .habit(id):
            kind = .habit
            label = ""
            habitID = id
        case nil:
            kind = .general
            label = ""
            habitID = active.first?.id
        }
    }

    var title: String { editing == nil ? "New Reminder" : "Edit Reminder" }

    func toggle(_ day: Weekday) {
        if weekdays.contains(day) {
            weekdays.remove(day)
        } else {
            weekdays.insert(day)
        }
    }

    /// Saves; returns `false` and sets `errorMessage` when refused.
    func save() -> Bool {
        guard let reminderTime = ReminderTimeConversion.time(from: time) else {
            errorMessage = "Pick a time."
            return false
        }
        let reminderKind: ReminderKind
        switch kind {
        case .general:
            reminderKind = .general(label: label.trimmingCharacters(in: .whitespacesAndNewlines))
        case .habit:
            guard let habitID else {
                errorMessage = habitChoices.isEmpty ? "Add a habit first, then remind yourself of it." : "Pick a habit."
                return false
            }
            reminderKind = .habit(habitID)
        }
        let repository = services.reminderRepository()
        do {
            if let editing {
                let changed = Reminder(id: editing.id, kind: reminderKind, time: reminderTime, weekdays: weekdays)
                try repository.update(changed)
            } else {
                try repository.create(kind: reminderKind, time: reminderTime, weekdays: weekdays)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete() -> Bool {
        guard let editing else { return false }
        do {
            try services.reminderRepository().delete(id: editing.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
